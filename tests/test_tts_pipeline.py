"""Dependency-free pipeline regression tests; synthesis and CUDA are mocked."""
import contextlib
import importlib
import io
import os
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest.mock import Mock, patch

SCRIPTS = Path(__file__).resolve().parents[1] / 'scripts'
sys.path.insert(0, str(SCRIPTS))

# Load the real application modules without requiring multi-GB ML dependencies.
torch = types.ModuleType('torch')
torch.set_num_threads = Mock()
torch.cuda = Mock()
torch.cuda.is_available.return_value = False
torch.no_grad = contextlib.nullcontext
torch.inference_mode = contextlib.nullcontext
torch.Tensor = type('Tensor', (), {})
torch.OutOfMemoryError = type('OutOfMemoryError', (RuntimeError,), {})
for dtype in ('float16', 'bfloat16', 'float32'):
    setattr(torch, dtype, dtype)
pandas = types.ModuleType('pandas')
pandas.notna = lambda x: x is not None
soundfile = types.ModuleType('soundfile')
soundfile.info = Mock(return_value=types.SimpleNamespace(duration=5))
yaml = types.ModuleType('yaml')
yaml.safe_load = Mock(return_value={})
with patch.dict(sys.modules, {'torch': torch, 'pandas': pandas, 'soundfile': soundfile, 'yaml': yaml}):
    core = importlib.import_module('core')
    generator = importlib.import_module('generator')
    backend = importlib.import_module('omnivoice_backend')
    db_adapter = importlib.import_module('db_adapter')


class Audio:
    def squeeze(self): return self
    def __mul__(self, _): return self
    def clip(self, *_): return self
    def astype(self, _): return b'audio'


class Writer:
    def __init__(self, path, **_): self.path = path
    def __enter__(self):
        self.file = open(self.path, 'wb')
        return self
    def write(self, data): self.file.write(data)
    def __exit__(self, *_): self.file.close()


class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.output = contextlib.redirect_stdout(io.StringIO())
        self.output.__enter__()
        self.modules = patch.dict(sys.modules, {'torch': torch, 'soundfile': soundfile})
        self.modules.start()
        soundfile.info.return_value = types.SimpleNamespace(duration=5)
        torch.cuda.is_available.return_value = False
        generator._seen_quest_id_dialog_type.clear()

    def tearDown(self):
        self.modules.stop()
        self.output.__exit__(None, None, None)

    def test_paths_and_metadata_work_from_any_directory(self):
        original = Path.cwd()
        try:
            for cwd in (SCRIPTS, SCRIPTS.parent, Path('/tmp')):
                os.chdir(cwd)
                self.assertTrue(Path(core.CONFIG['npc_metadata_json']).is_file())
                self.assertTrue(db_adapter.load_npc_metadata())
                self.assertTrue(generator.build_ref_codes())
                self.assertEqual(core.CONFIG['wtf_path'], str(SCRIPTS.parents[3] / 'WTF'))
        finally:
            os.chdir(original)

    def test_chunk_limit_and_text_order(self):
        for text in ('A short sentence. ' + 'long ' * 250 + 'Done!',
                     'short. ' * 200, 'x' * 1200, 'One… Two? Three! Four;'):
            chunks = generator.chunk_text_robust(text, max_chars=100)
            self.assertTrue(all(0 < len(c) <= 100 for c in chunks))
            self.assertEqual(''.join(''.join(chunks).split()), ''.join(text.split()))

    def test_empty_chunks(self):
        self.assertEqual(generator.chunk_text_robust(''), [])
        self.assertEqual(generator.chunk_text_robust('   '), [])

    def test_cli_defaults_and_invalid_limits(self):
        with patch.object(sys, 'argv', ['core.py']):
            args = core.parse_args()
        self.assertEqual((args.device, args.tts_steps), ('auto', 32))
        for option, value in (('--tts-chunk-chars', '0'), ('--prompt-cache-size', '-1'),
                              ('--max-retries', '0'), ('--gpu-memory-fraction', '1.1'),
                              ('--tts-speed', 'nan')):
            with patch.object(sys, 'argv', ['core.py', option, value]), contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit): core.parse_args()

    def test_low_system_memory_stops(self):
        with patch.object(Path, 'read_text', return_value='MemAvailable: 1024 kB\n'):
            with self.assertRaises(MemoryError): backend.check_system_memory()

    def test_auto_cpu_load_uses_reduced_precision(self):
        model = Mock(sampling_rate=24000)
        omni = types.SimpleNamespace(OmniVoice=Mock())
        omni.OmniVoice.from_pretrained.return_value = model
        with patch.dict(sys.modules, {'omnivoice': omni}), patch.object(backend, 'check_system_memory'):
            backend.OmniVoiceBackend.from_pretrained()
        kwargs = omni.OmniVoice.from_pretrained.call_args.kwargs
        self.assertEqual(kwargs['device_map'], 'cpu')
        self.assertEqual(kwargs['dtype'], 'bfloat16')
        self.assertEqual(kwargs['asr_device'], 'cpu')
        self.assertFalse(kwargs['load_asr'])
        model.eval.assert_called_once()

    def test_cuda_allocator_cap_is_set_before_loading(self):
        torch.cuda.is_available.return_value = True
        omni = types.SimpleNamespace(OmniVoice=Mock())
        def load(*args, **kwargs):
            torch.cuda.set_per_process_memory_fraction.assert_called_with(0.7, device=0)
            return Mock(sampling_rate=24000)
        omni.OmniVoice.from_pretrained.side_effect = load
        with patch.dict(sys.modules, {'omnivoice': omni}), patch.object(backend, 'check_system_memory'):
            backend.OmniVoiceBackend.from_pretrained(device='cuda', gpu_memory_fraction=0.7)

    def test_prompt_lru_is_bounded_on_cpu(self):
        model = Mock(sampling_rate=24000)
        model.create_voice_clone_prompt.side_effect = lambda **_: types.SimpleNamespace(ref_audio_tokens=Mock())
        tts = backend.OmniVoiceBackend(model, prompt_cache_size=2)
        with patch.object(tts, '_load_reference_text', return_value='Reference transcript'):
            first = tts._get_voice_clone_prompt('a.wav')
            tts._get_voice_clone_prompt('b.wav')
            self.assertIs(first, tts._get_voice_clone_prompt('a.wav'))
            tts._get_voice_clone_prompt('c.wav')
        self.assertEqual([Path(k).name for k in tts._prompt_cache], ['a.wav', 'c.wav'])
        self.assertEqual(model.create_voice_clone_prompt.call_count, 3)
        model.load_asr_model.assert_not_called()

    def test_missing_transcript_loads_asr_once_on_cpu(self):
        model = Mock(sampling_rate=24000)
        tts = backend.OmniVoiceBackend(model)
        with patch.object(tts, '_load_reference_text', return_value=None):
            tts._get_voice_clone_prompt('a.wav')
            tts._get_voice_clone_prompt('b.wav')
        model.load_asr_model.assert_called_once_with(model_name='openai/whisper-tiny.en', device='cpu')

    def test_long_reference_rejected_before_encoding(self):
        soundfile.info.return_value = types.SimpleNamespace(duration=120)
        model = Mock(sampling_rate=24000)
        tts = backend.OmniVoiceBackend(model)
        with patch.object(tts, '_load_reference_text', return_value='Full recording transcript'):
            with self.assertRaises(ValueError): tts._get_voice_clone_prompt('long.wav')
        model.create_voice_clone_prompt.assert_not_called()

    def test_long_reference_without_transcript_reads_bounded_excerpt(self):
        soundfile.info.return_value = types.SimpleNamespace(duration=120, samplerate=24000)
        model = Mock(sampling_rate=24000)
        tts = backend.OmniVoiceBackend(model)
        with patch.object(tts, '_load_reference_text', return_value=None), \
             patch.object(soundfile, 'read', return_value=(Mock(), 24000), create=True) as read, \
             patch.object(torch, 'from_numpy', return_value='bounded tensor', create=True):
            tts._get_voice_clone_prompt('long.wav')
        read.assert_called_once_with('long.wav', frames=240000, dtype='float32', always_2d=True)
        model.create_voice_clone_prompt.assert_called_once_with(
            ref_audio=('bounded tensor', 24000), ref_text=None)

    def run_row(self, folder, tts):
        return generator.generate_tts_for_row(
            {'npc_name': 'Test', 'dialog_type': 'gossip', 'text': 'hello world ' * 50},
            tts, {'human_male': {'audio_path': 'ref.wav'}},
            {'Test': {'race': 'human', 'sex': 'male'}}, folder,
            regenerate=True, retry_wait=0,
        )

    def test_oom_retries_smaller_chunks_and_publishes_complete_file(self):
        lengths = []
        def synthesize(text, **_):
            lengths.append(len(text))
            if len(text) > 100: raise torch.OutOfMemoryError('out of memory')
            return Audio()
        tts = Mock(sampling_rate=24000, generate=Mock(side_effect=synthesize))
        with tempfile.TemporaryDirectory() as folder, patch.object(soundfile, 'SoundFile', Writer, create=True):
            result = self.run_row(folder, tts)
            self.assertTrue(Path(result).read_bytes())
            self.assertFalse(list(Path(folder).rglob('.tts-*')))
        self.assertGreater(lengths[0], 100)
        self.assertTrue(all(n <= 100 for n in lengths[1:]))
        tts.clear_prompt_cache.assert_called_once()

    def test_failed_regeneration_preserves_previous_wav(self):
        tts = Mock(sampling_rate=24000, generate=Mock(return_value=Audio()))
        with tempfile.TemporaryDirectory() as folder, patch.object(soundfile, 'SoundFile', Writer, create=True):
            path = Path(self.run_row(folder, tts))
            original = path.read_bytes()
            tts.generate.side_effect = torch.OutOfMemoryError('out of memory')
            with self.assertRaises(MemoryError): self.run_row(folder, tts)
            self.assertEqual(path.read_bytes(), original)
            self.assertFalse(list(Path(folder).rglob('.tts-*')))

    def test_interrupt_removes_partial_file(self):
        tts = Mock(sampling_rate=24000, generate=Mock(side_effect=[Audio(), KeyboardInterrupt()]))
        with tempfile.TemporaryDirectory() as folder, patch.object(soundfile, 'SoundFile', Writer, create=True):
            with self.assertRaises(KeyboardInterrupt): self.run_row(folder, tts)
            self.assertFalse(list(Path(folder).rglob('*.wav')))

    def test_cuda_errors_are_not_misclassified_as_oom(self):
        tts = Mock(sampling_rate=24000, generate=Mock(side_effect=RuntimeError('CUDA invalid device function')))
        with tempfile.TemporaryDirectory() as folder, patch.object(soundfile, 'SoundFile', Writer, create=True):
            self.assertIsNone(self.run_row(folder, tts))
        self.assertEqual(tts.generate.call_count, 1)

    def test_gpu_pressure_includes_other_processes_and_stops(self):
        torch.cuda.is_available.return_value = True
        torch.cuda.memory_allocated.return_value = 1 * 1024**3
        torch.cuda.memory_reserved.return_value = 2 * 1024**3
        torch.cuda.mem_get_info.return_value = (1 * 1024**3, 10 * 1024**3)
        self.assertAlmostEqual(generator.get_gpu_memory_info()['usage_percent'], 0.9)
        self.assertFalse(generator.wait_for_gpu_memory(wait_seconds=0, max_retries=1))


if __name__ == '__main__':
    unittest.main()
