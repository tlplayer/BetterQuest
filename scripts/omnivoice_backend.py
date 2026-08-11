"""OmniVoice adapter for BetterQuest's reference-sample TTS pipeline."""

from pathlib import Path


class OmniVoiceBackend:
    """Load OmniVoice and cache one reusable clone prompt per sample."""

    def __init__(
        self,
        model,
        *,
        language="English",
        num_step=16,
        speed=1.0,
        asr_model_name="openai/whisper-tiny.en",
    ):
        self.model = model
        self.language = language
        self.num_step = num_step
        self.speed = speed
        self.asr_model_name = asr_model_name
        self.sampling_rate = model.sampling_rate
        self._prompt_cache = {}
        self._asr_loaded = False

    @classmethod
    def from_pretrained(
        cls,
        model_name="k2-fsa/OmniVoice",
        *,
        device="cuda",
        language="English",
        num_step=16,
        speed=1.0,
        asr_model_name="openai/whisper-tiny.en",
    ):
        from omnivoice import OmniVoice
        import torch

        device_map = "cuda:0" if device == "cuda" else device
        dtype = torch.float16 if device == "cuda" else torch.float32
        model = OmniVoice.from_pretrained(
            model_name,
            device_map=device_map,
            dtype=dtype,
        )
        return cls(
            model,
            language=language,
            num_step=num_step,
            speed=speed,
            asr_model_name=asr_model_name,
        )

    @staticmethod
    def _load_reference_text(audio_path):
        transcript_path = Path(audio_path).with_suffix(".txt")
        if not transcript_path.is_file():
            return None
        transcript = transcript_path.read_text(encoding="utf-8").strip()
        return transcript or None

    def _get_voice_clone_prompt(self, audio_path):
        cache_key = str(Path(audio_path).resolve())
        if cache_key in self._prompt_cache:
            return self._prompt_cache[cache_key]

        ref_text = self._load_reference_text(audio_path)
        if ref_text is None and not self._asr_loaded:
            print(f"[INFO] Loading reference-sample ASR model: {self.asr_model_name}")
            self.model.load_asr_model(model_name=self.asr_model_name)
            self._asr_loaded = True

        prompt = self.model.create_voice_clone_prompt(
            ref_audio=audio_path,
            ref_text=ref_text,
        )
        self._prompt_cache[cache_key] = prompt
        return prompt

    def generate(self, text, *, audio_prompt_path):
        prompt = self._get_voice_clone_prompt(audio_prompt_path)
        audio = self.model.generate(
            text=text,
            language=self.language,
            voice_clone_prompt=prompt,
            num_step=self.num_step,
            speed=self.speed,
        )
        if not audio:
            raise RuntimeError("OmniVoice returned no audio")
        return audio[0]
