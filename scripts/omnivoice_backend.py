"""OmniVoice adapter with bounded reference caching and inference memory use."""

from collections import OrderedDict
from pathlib import Path


def check_system_memory(min_available_gb=2.0):
    """Stop between allocations when Linux reports critically low available RAM.

    This is a headroom check, not a hard limit on native library allocations.
    """
    try:
        lines = Path('/proc/meminfo').read_text().splitlines()
    except OSError:
        return
    for line in lines:
        if line.startswith('MemAvailable:'):
            available = int(line.split()[1]) / 1024**2
            if available < min_available_gb:
                raise MemoryError(
                    f"Only {available:.1f} GiB RAM available; stopping to avoid swap thrashing. "
                    "Close other applications before restarting. Completed audio is reusable."
                )
            return


class OmniVoiceBackend:
    def __init__(self, model, *, language="English", num_step=32, speed=1.0,
                 asr_model_name="openai/whisper-tiny.en", prompt_cache_size=8):
        if prompt_cache_size < 1:
            raise ValueError("prompt_cache_size must be positive")
        self.model = model
        self.device = str(model.device)
        self.language = language
        self.num_step = num_step
        self.speed = speed
        self.asr_model_name = asr_model_name
        self.sampling_rate = model.sampling_rate
        self.prompt_cache_size = prompt_cache_size
        self._prompt_cache = OrderedDict()
        self._asr_loaded = False

    @classmethod
    def from_pretrained(cls, model_name="k2-fsa/OmniVoice", *, device="auto",
                        language="English", num_step=32, speed=1.0,
                        asr_model_name="openai/whisper-tiny.en", dtype="auto",
                        prompt_cache_size=8, gpu_memory_fraction=0.8, cpu_threads=4):
        import torch
        from omnivoice import OmniVoice

        if cpu_threads < 1:
            raise ValueError("cpu_threads must be positive")
        torch.set_num_threads(cpu_threads)
        if device == "auto":
            device = "cuda" if torch.cuda.is_available() else "cpu"
        if device == "cuda":
            if not torch.cuda.is_available():
                raise ValueError("CUDA is unavailable; use --device cpu or --device auto")
            if not 0 < gpu_memory_fraction <= 1:
                raise ValueError("gpu_memory_fraction must be in (0, 1]")
            torch.cuda.set_per_process_memory_fraction(gpu_memory_fraction, device=0)
        if dtype == "auto":
            dtype = "bfloat16" if device == "cpu" or torch.cuda.is_bf16_supported() else "float16"
        if device == "cpu" and dtype == "float16":
            raise ValueError("Use bfloat16 or float32 for CPU inference")
        check_system_memory()
        print(f"[INFO] OmniVoice device={device}, dtype={dtype}, prompt cache={prompt_cache_size}")
        try:
            model = OmniVoice.from_pretrained(
                model_name,
                device_map="cuda:0" if device == "cuda" else device,
                dtype=getattr(torch, dtype),
                attn_implementation="sdpa",
                load_asr=False,
                asr_model_name=asr_model_name,
                asr_device="cpu",
            )
        except torch.OutOfMemoryError as exc:
            raise MemoryError(
                "OmniVoice could not fit in memory during loading. Close other applications "
                "or try --device cpu --tts-dtype bfloat16."
            ) from exc
        model.eval()
        return cls(model, language=language, num_step=num_step, speed=speed,
                   asr_model_name=asr_model_name, prompt_cache_size=prompt_cache_size)

    @staticmethod
    def _load_reference_text(audio_path):
        transcript_path = Path(audio_path).with_suffix(".txt")
        if not transcript_path.is_file():
            return None
        return transcript_path.read_text(encoding="utf-8").strip() or None

    def clear_prompt_cache(self):
        self._prompt_cache.clear()

    def _get_voice_clone_prompt(self, audio_path):
        import soundfile as sf
        import torch

        cache_key = str(Path(audio_path).resolve())
        if cache_key in self._prompt_cache:
            self._prompt_cache.move_to_end(cache_key)
            return self._prompt_cache[cache_key]

        # Inspect the header before OmniVoice reads/encodes an entire recording.
        info = sf.info(audio_path)
        ref_text = self._load_reference_text(audio_path)
        if info.duration <= 0:
            raise ValueError(f"Reference {audio_path} is empty")
        ref_audio = audio_path
        if info.duration > 20:
            if ref_text is not None:
                raise ValueError(f"Reference {audio_path} exceeds 20 seconds; shorten the WAV and its transcript together")
            # Transcribe only the bounded excerpt; never pair cropped audio with
            # a transcript for the full recording. Leave the source WAV intact.
            waveform, sample_rate = sf.read(
                audio_path, frames=int(info.samplerate * 10), dtype="float32", always_2d=True
            )
            ref_audio = (torch.from_numpy(waveform.T), sample_rate)
            print(f"[INFO] Using the first 10 seconds of long reference: {audio_path}")
        while len(self._prompt_cache) >= self.prompt_cache_size:
            self._prompt_cache.popitem(last=False)
        if ref_text is None and not self._asr_loaded:
            print(f"[INFO] Loading reference-sample ASR on CPU: {self.asr_model_name}")
            self.model.load_asr_model(model_name=self.asr_model_name, device="cpu")
            self._asr_loaded = True
        prompt = self.model.create_voice_clone_prompt(ref_audio=ref_audio, ref_text=ref_text)
        prompt.ref_audio_tokens = prompt.ref_audio_tokens.detach().cpu()
        self._prompt_cache[cache_key] = prompt
        return prompt

    def generate(self, text, *, audio_prompt_path):
        import torch

        check_system_memory()
        with torch.inference_mode():
            prompt = self._get_voice_clone_prompt(audio_prompt_path)
            audio = self.model.generate(
                text=text, language=self.language, voice_clone_prompt=prompt,
                num_step=self.num_step, speed=self.speed,
                audio_chunk_duration=10.0, audio_chunk_threshold=15.0,
            )
        if not audio:
            raise RuntimeError("OmniVoice returned no audio")
        return audio[0]
