
import sys
import json
import argparse
from pathlib import Path

import numpy as np
import matplotlib.pyplot as plt

from bomc1 import Device, Frame


def _do_sum_average(frames: np.array) -> np.array:
    return np.mean(frames, axis=0)


def _do_moving_average(frame: np.array) -> np.array:
    n = 10
    frame = np.cumsum(frame)
    frame[n:] = frame[n:] - frame[:-n]
    r = frame[n-1:] / n
    print(frame[n-1:].size)
    return r


def _do_full_average(frames: list[Frame]) -> np.array:
    savg = _do_sum_average(np.asarray(frames, dtype=np.uint16))
    return _do_moving_average(savg)


def _do_dark_current(frame: np.array) -> np.array:
    with open('samples_data/dc.json') as fp:
        dc_frames = json.load(fp)

    print(frame, frame.size)
    avg = _do_full_average(dc_frames)
    print(avg, avg.size)

    return frame - avg


def _do_render(frames: list[Frame], raw: bool, avg_only: bool) -> None:
    # _, axs = plt.subplots(len(frames))

    if not avg_only:
        for idx, x in enumerate(frames):
            # ax = axs[idx] if len(frames) != 1 else axs
            plt.plot(x)

    if not raw:
        avg = _do_sum_average(np.asarray(frames, dtype=np.uint16))
        plt.plot(avg)
        mavg = _do_moving_average(avg)
        plt.plot(mavg)

        dc = _do_dark_current(mavg)
        plt.plot(dc)
    else:
        plt.plot(frames)

    plt.show()


def _do_save(frames: list[Frame], out: Path) -> None:
    with open(out, 'w', encoding='utf-8') as fp:
        json.dump(frames, fp)


def _do_fetch(args: argparse.Namespace) -> None:
    dev = Device.first()
    frames: list[Frame] = []

    for i in range(args.n):
        frames.append(dev.read_frame())

    if args.save:
        _do_save(frames, args.out)

    if args.render:
        _do_render(frames, raw=args.raw, avg_only=args.avg_only)


def _do_conf(args: argparse.Namespace) -> None:
    dev = Device.first()

    if args.set:
        setattr(dev, args.field, args.set)
    else:
        print(getattr(dev, args.field))


def _create_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    subs = parser.add_subparsers()

    fetch = subs.add_parser('fetch')
    fetch.add_argument('-n', type=int, default=1, help='Count to fetch')
    fetch.add_argument('-s', '--save', action='store_true')
    fetch.add_argument('-r', '--render', action='store_true')
    fetch.add_argument('-o', '--out', type=Path)
    fetch.add_argument('--raw', action='store_true')
    fetch.add_argument('--avg-only', action='store_true')
    fetch.set_defaults(func=_do_fetch)

    inttime = subs.add_parser('conf')
    inttime.add_argument('field', type=str)
    inttime.add_argument('-s', '--set', type=int)
    inttime.set_defaults(func=_do_conf)

    return parser


def entrypoint() -> None:
    parser = _create_parser()
    parsed = parser.parse_args(sys.argv[1:])
    parsed.func(parsed)

    pass
