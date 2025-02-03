
zephyr_library()

zephyr_library_sources_ifdef(CONFIG_TOSHIBA_TCD1304 ccd_tcd1304.c)
