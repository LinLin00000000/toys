from faster_whisper import WhisperModel

# 设置模型参数
model_size = "base"  # 模型大小，可选择 "tiny", "base", "small", "medium", "large"
device = "cpu"  # 使用 GPU，如果没有 GPU，可改为 "cpu"
compute_type = "int8"  # 使用 float16 类型加速计算
model = WhisperModel(model_size, device=device, compute_type=compute_type)

# 音频文件路径
audio_path = r"C:\Users\Lin\Downloads\848841213_nb3-1-16.mp3"

# 输出文件路径
output_file = r"C:\Users\Lin\Downloads\transcription.txt"

# 执行转录
print("正在进行转录，请稍候...")
segments, info = model.transcribe(audio_path, beam_size=5)

# 打印检测到的语言信息
print("检测到的语言:", info.language)
print("语言概率:", info.language_probability)

# 初始化保存去掉时间戳的文本列表
transcripts = []

# 遍历片段，打印带时间戳的结果并保存无时间戳文本
for segment in segments:
    # 带时间戳的输出到控制台
    print("[%.2fs -> %.2fs] %s" % (segment.start, segment.end, segment.text))
    # 保存去掉时间戳的文本到列表
    transcripts.append(segment.text)

# 将去掉时间戳的文本一次性写入文件
with open(output_file, "w", encoding="utf-8") as f:
    f.write("\n".join(transcripts) + "\n")

print(f"\n转录完成，去时间戳文本已保存到: {output_file}")
