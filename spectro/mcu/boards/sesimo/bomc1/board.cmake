
board_runner_args(jlink "--device=STM32F103RB" "--speed=4000" "--iface=jtag")

include(${ZEPHYR_BASE}/boards/common/openocd.board.cmake)
include(${ZEPHYR_BASE}/boards/common/jlink.board.cmake)
