"""将 RVC safetensors 模型及同名 JSON 配置转换为 .pth。"""
import argparse
import json
from pathlib import Path

import torch
from safetensors.torch import load_file


def main():
    model_dir = Path(__file__).resolve().parent / "model"
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", nargs="?", help="输入 .safetensors 文件")
    parser.add_argument("output", nargs="?", help="输出 .pth 文件，默认与输入同名")
    args = parser.parse_args()

    source = Path(args.input).resolve() if args.input else model_dir / "xiaoxiao.safetensors"
    target = Path(args.output).resolve() if args.output else source.with_suffix(".pth")
    config_path = source.with_suffix(".json")
    if not source.is_file():
        raise FileNotFoundError(f"找不到输入模型：{source}")
    if not config_path.is_file():
        raise FileNotFoundError(f"找不到同名 JSON 配置：{config_path}")

    state_dict = load_file(str(source))
    with config_path.open("r", encoding="utf-8") as handle:
        config = json.load(handle)
    keys = list(state_dict)
    if keys and keys[0].startswith("weight."):
        state_dict = {key[len("weight."):]: value for key, value in state_dict.items()}

    checkpoint = {
        "config": config["config"],
        "weight": state_dict,
        "f0": config.get("f0", 1),
        "version": config.get("version", "v2"),
        "info": config.get("info", ""),
    }
    target.parent.mkdir(parents=True, exist_ok=True)
    torch.save(checkpoint, str(target))
    sample_rate = config.get("config", [None])[-1]
    embedding = state_dict.get("emb_g.weight")
    speaker_count = embedding.shape[0] if embedding is not None else "未知"
    print(f"saved: {target} sr: {sample_rate} emb_g: {speaker_count}")


if __name__ == "__main__":
    main()
