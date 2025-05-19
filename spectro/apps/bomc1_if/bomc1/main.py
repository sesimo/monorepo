
import sys
import json
import argparse
from pathlib import Path

import matplotlib.pyplot as plt

from bomc1 import Device, Frame


def _do_render(frames: list[Frame]) -> None:
    for idx, x in enumerate(frames):
        plt.plot(x)

    plt.show()


def _do_save(frames: list[Frame], out: Path) -> None:
    with open(out, 'w', encoding='utf-8') as fp:
        json.dump(frames, fp)


def _do_fetch(args: argparse.Namespace) -> None:
    dev = Device.first()
    frames: list[Frame] = []

    for i in range(args.n):
        frames.append(dev.read_frame(dc=not args.no_dc,
                      movavg=not args.no_movavg, totavg=not args.no_totavg))

    if args.with_raw != 0:
        for i in range(args.with_raw):
            frames.append(dev.read_frame(False, False, False))

    if args.save:
        _do_save(frames, args.out)

    if args.render:
        _do_render(frames)


def _do_conf(args: argparse.Namespace) -> None:
    dev = Device.first()

    if args.set:
        if not hasattr(dev, args.field):
            raise AttributeError(args.field)

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
    fetch.add_argument('--no-dc', action='store_true')
    fetch.add_argument('--no-totavg', action='store_true')
    fetch.add_argument('--no-movavg', action='store_true')
    fetch.add_argument('--with-raw', type=int, default=0)
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
