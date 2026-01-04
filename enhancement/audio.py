from clearvoice import ClearVoice

cv = ClearVoice(task="speech_super_resolution", model_names=["MossFormer2_SR_48K"])
enhanced = cv(input_path="3255.wav", online_write=False)
cv.write(enhanced, output_path="3255_clearvoice.wav")
