#!/usr/bin/env python3
import argparse
import json
import shutil
import subprocess
from datetime import datetime, timezone
from pathlib import Path


GROUP_TITLES = {
    "featured": "精选",
    "animals": "动物",
    "motion": "运动",
    "objects": "物件",
    "scenes": "场景",
    "symbols": "图形",
}

RUNCAT_ASSET_METADATA = {
    "all-runners": ("全员奔跑", "motion"),
    "bird": ("小鸟", "animals"),
    "bonfire": ("篝火", "scenes"),
    "butterfly": ("蝴蝶", "animals"),
    "cat": ("RunCat 猫", "animals"),
    "cat-b": ("RunCat 猫 B", "animals"),
    "cat-c": ("RunCat 猫 C", "animals"),
    "cat-tail": ("猫尾巴", "animals"),
    "chameleon": ("变色龙", "animals"),
    "cheetah": ("猎豹", "animals"),
    "chicken": ("小鸡", "animals"),
    "city": ("城市", "scenes"),
    "coffee": ("咖啡", "objects"),
    "cogwheel": ("齿轮", "objects"),
    "cradle": ("摇篮", "objects"),
    "dinosaur": ("恐龙", "animals"),
    "dog": ("小狗", "animals"),
    "dogeza": ("伏地", "motion"),
    "dolphin": ("海豚", "animals"),
    "dots": ("圆点", "symbols"),
    "dragon": ("龙", "animals"),
    "drop": ("水滴", "symbols"),
    "earth": ("地球", "scenes"),
    "engine": ("发动机", "objects"),
    "entaku": ("圆桌", "objects"),
    "factory": ("工厂", "scenes"),
    "fishman": ("鱼人", "animals"),
    "flash-cat": ("闪电猫", "featured"),
    "fox": ("狐狸", "animals"),
    "frog": ("青蛙", "animals"),
    "frypan": ("煎锅", "objects"),
    "ghost": ("幽灵", "symbols"),
    "golden-cat": ("金猫", "featured"),
    "greyhound": ("灵缇", "animals"),
    "hamster-wheel": ("转轮", "motion"),
    "hedgehog": ("刺猬", "animals"),
    "horse": ("马", "animals"),
    "human": ("跑步人", "motion"),
    "jack-o-lantern": ("南瓜灯", "objects"),
    "maneki-neko": ("招财猫", "featured"),
    "metal-cluster-cat": ("金属猫", "featured"),
    "mochi": ("麻薯", "objects"),
    "mock-nyan-cat": ("彩虹猫", "featured"),
    "mouse": ("小鼠", "animals"),
    "octopus": ("章鱼", "animals"),
    "otter": ("水獭", "animals"),
    "owl": ("猫头鹰", "animals"),
    "parrot": ("鹦鹉", "animals"),
    "party-people": ("派对人群", "motion"),
    "pendulum": ("钟摆", "objects"),
    "penguin": ("企鹅", "animals"),
    "penguin2": ("企鹅 2", "animals"),
    "pig": ("小猪", "animals"),
    "pulse": ("脉冲", "symbols"),
    "puppy": ("幼犬", "animals"),
    "push-up": ("俯卧撑", "motion"),
    "rabbit": ("兔子", "animals"),
    "reactor": ("反应堆", "objects"),
    "reindeer-sleigh": ("雪橇", "scenes"),
    "rocket": ("火箭", "objects"),
    "rotating-sushi": ("旋转寿司", "objects"),
    "rubber-duck": ("小黄鸭", "objects"),
    "sausage": ("香肠", "objects"),
    "self-made": ("自制", "symbols"),
    "sheep": ("绵羊", "animals"),
    "sine-curve": ("正弦曲线", "symbols"),
    "sit-up": ("仰卧起坐", "motion"),
    "slime": ("史莱姆", "symbols"),
    "snowman": ("雪人", "scenes"),
    "sparkler": ("烟花棒", "objects"),
    "squirrel": ("松鼠", "animals"),
    "steam-locomotive": ("蒸汽火车", "objects"),
    "sushi": ("寿司", "objects"),
    "tapioca-drink": ("珍珠奶茶", "objects"),
    "terrier": ("梗犬", "animals"),
    "triforce": ("三角徽记", "symbols"),
    "uhooi": ("Uhooi", "symbols"),
    "welsh-corgi": ("柯基", "animals"),
    "whale": ("鲸鱼", "animals"),
    "wind-chime": ("风铃", "objects"),
}


def make_zip(source_dir: Path, archive_url: Path) -> None:
    if archive_url.exists():
        archive_url.unlink()
    subprocess.run(
        ["/usr/bin/ditto", "-c", "-k", "--sequesterRsrc", "--rsrc", str(source_dir), str(archive_url)],
        check=True,
    )


def copy_frames(source_files: list[Path], target_dir: Path) -> None:
    frames_dir = target_dir / "frames"
    frames_dir.mkdir(parents=True, exist_ok=True)

    for index, source in enumerate(source_files):
        shutil.copy2(source, frames_dir / f"frame-{index:03d}.png")

    shutil.copy2(frames_dir / "frame-000.png", target_dir / "preview.png")


def add_asset(
    catalog_assets: list[dict],
    used_categories: list[str],
    source_files: list[Path],
    assets_dir: Path,
    asset_id: str,
    title: str,
    category: str,
    frame_duration: float,
    use_zip: bool,
) -> None:
    target_dir = assets_dir / asset_id
    target_dir.mkdir(parents=True, exist_ok=True)
    copy_frames(source_files, target_dir)

    entry = {
        "id": asset_id,
        "title": title,
        "categoryID": category,
        "version": "1",
        "previewPath": f"assets/{asset_id}/preview.png",
        "frameCount": len(source_files),
        "frameDuration": frame_duration,
    }

    if use_zip:
        make_zip(target_dir / "frames", target_dir / "asset.zip")
        entry["archivePath"] = f"assets/{asset_id}/asset.zip"
        entry["archiveFramePathPattern"] = "frame-%03d.png"
    else:
        entry["framePathPattern"] = f"assets/{asset_id}/frames/frame-%03d.png"

    catalog_assets.append(entry)
    if category not in used_categories:
        used_categories.append(category)


def sorted_pngs(directory: Path) -> list[Path]:
    return sorted(directory.glob("*.png"))


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate an icon gallery catalog and static assets.")
    parser.add_argument("--resources-dir", default="Sources/Resources")
    parser.add_argument("--output-dir", default="build/LocalIconGallery")
    parser.add_argument("--catalog-name", default="catalog.dev.json")
    parser.add_argument("--base-url", help="Catalog baseURL. Defaults to a file:// URL for the output directory.")
    parser.add_argument("--no-zip", action="store_true", help="Use individual frame files instead of archivePath.")
    args = parser.parse_args()

    resources_dir = Path(args.resources_dir).resolve()
    output_dir = Path(args.output_dir).resolve()
    assets_dir = output_dir / "assets"
    use_zip = not args.no_zip

    if output_dir.exists():
        shutil.rmtree(output_dir)
    assets_dir.mkdir(parents=True, exist_ok=True)

    catalog_assets: list[dict] = []
    used_categories: list[str] = []

    add_asset(
        catalog_assets,
        used_categories,
        [resources_dir / "BuiltinMenuBarAnimations" / "RunCat" / f"cat{index}.png" for index in range(5)],
        assets_dir,
        "runcat",
        "RunCat",
        "featured",
        0.1,
        use_zip,
    )
    add_asset(
        catalog_assets,
        used_categories,
        [resources_dir / "BuiltinMenuBarAnimations" / "RunningLeft" / f"runningLeft{index:03d}.png" for index in range(1, 53)],
        assets_dir,
        "running-left",
        "奔跑狗狗",
        "featured",
        1.0 / 24.0,
        use_zip,
    )

    runcat_assets_dir = resources_dir / "BuiltinMenuBarAnimations" / "RunCatAssets"
    for source_dir in sorted(p for p in runcat_assets_dir.iterdir() if p.is_dir()):
        source_files = sorted_pngs(source_dir)
        if not source_files:
            continue

        title, category = RUNCAT_ASSET_METADATA.get(source_dir.name, (source_dir.name, "objects"))
        add_asset(
            catalog_assets,
            used_categories,
            source_files,
            assets_dir,
            f"runcat-{source_dir.name}",
            title,
            category,
            0.1,
            use_zip,
        )

    catalog = {
        "schemaVersion": 1,
        "generatedAt": datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
        "baseURL": args.base_url or (output_dir.as_uri() + "/"),
        "categories": [
            {"id": category, "title": GROUP_TITLES[category]}
            for category in used_categories
        ],
        "assets": catalog_assets,
    }

    catalog_path = output_dir / args.catalog_name
    catalog_path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Icon catalog: {catalog_path}")
    print(f"Assets: {len(catalog_assets)}")


if __name__ == "__main__":
    main()
