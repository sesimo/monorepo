import usb


dev = usb.core.find(idVendor=0xF005, idProduct=0x1)
#dev = usb.core.find(idVendor=0x2fe3, idProduct=0x1)
dev.reset()

if 1:
    dev.set_configuration()
    cfg = dev.get_active_configuration()
    iface = cfg[(0, 0)]

    def ep_match(kind):
        def _match(e):
            return usb.util.endpoint_direction(e.bEndpointAddress) == kind

        return _match

    print(iface)
    ep_r = usb.util.find_descriptor(iface, custom_match=ep_match(usb.util.ENDPOINT_IN))
    #ep_w = usb.util.find_descriptor(iface, custom_match=ep_match(usb.util.ENDPOINT_OUT))

    dev.ctrl_transfer(0x00 | (0x2 << 5), 0x1, 0, 0, "hello")

    #ep_w.write(b"hmm")
    ret = ep_r.read(3648*2, timeout=2000)

    with open('test.hex', 'wb') as fp:
        fp.write(ret)
else:
    dev.write(0x1, "huh")
