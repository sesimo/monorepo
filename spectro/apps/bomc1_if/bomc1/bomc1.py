
from __future__ import annotations
from typing import Any

import usb
import struct

SSM_VID = 0xf005
BOMC1_PID = 0x1

USB_MSG_RECIP_DEV = 0x0
USB_MSG_TYPE_VENDOR = 0x2
USB_MSG_TYPE_OFFSET = 5
USB_MSG_DIR_DEV = 0
USB_MSG_DIR_HOST = 1
USB_MSG_DIR_OFFSET = 7

# Vendor specific requests
VREQ_BEGIN_READ = 0x1
VREQ_INTEGRATION_TIME = 0x2

DATA_COUNT = 3648
DATA_SIZE = DATA_COUNT * 2


def _ep_find_kind(kind: int) -> callable:
    def match(e: usb.Endpoint) -> bool:
        return usb.util.endpoint_direction(e.bEndpointAddress) == kind

    return match


class Frame(tuple):
    pass


class Device:
    _dev: usb.Device
    _timeout_ms: int

    def __init__(self, dev: usb.Device) -> None:
        self._dev = dev
        self._timeout_ms = 2000

    @property
    def intf(self) -> usb.Interface:
        return self._dev.get_active_configuration()[(0, 0)]

    @classmethod
    def find_devices(cls) -> list[usb.Device]:
        dev = usb.core.find(find_all=True, idVendor=SSM_VID,
                            idProduct=BOMC1_PID)
        return dev

    @classmethod
    def first(cls) -> Device:
        return cls(usb.core.find(idVendor=SSM_VID, idProduct=BOMC1_PID))

    def _ctrl_message(self, endpoint: int,
                      data_or_len: int | bytes | None = None,
                      direction: int = USB_MSG_DIR_DEV,
                      type_: int = USB_MSG_TYPE_VENDOR,
                      recip: int = USB_MSG_RECIP_DEV) -> Any:
        bmtype = recip | (type_ << USB_MSG_TYPE_OFFSET) | (
            direction << USB_MSG_DIR_OFFSET)

        return self._dev.ctrl_transfer(bmtype, endpoint, 0, 0, data_or_len)

    @property
    def integration_time(self) -> int:
        data = self._ctrl_message(
            VREQ_INTEGRATION_TIME, 4, direction=USB_MSG_DIR_HOST)
        return struct.unpack('<I', data)[0]

    @integration_time.setter
    def integration_time(self, t: int) -> None:
        data = struct.pack('<I', t)
        self._ctrl_message(
            VREQ_INTEGRATION_TIME, data, direction=USB_MSG_DIR_DEV)

    def _begin_read(self) -> None:
        self._ctrl_message(VREQ_BEGIN_READ)

    def _get_ep(self, kind: int) -> usb.core.Endpoint:
        return usb.util.find_descriptor(self.intf,
                                        custom_match=_ep_find_kind(kind))

    def read_frame(self) -> Frame:
        self._begin_read()

        ep = self._get_ep(usb.util.ENDPOINT_IN)
        data = ep.read(DATA_SIZE, timeout=self._timeout_ms)

        return Frame(struct.unpack(f'<{DATA_COUNT}H', data))
