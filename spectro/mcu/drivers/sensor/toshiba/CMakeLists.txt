
zephyr_library()

zephyr_library_sources_ifdef(CONFIG_TOSHIBA_TCD1304 tcd1304.c tcd1304_decode.c)
