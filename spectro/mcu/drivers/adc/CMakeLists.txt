
zephyr_library_amend()
zephyr_library_include_directories(${ZEPHYR_BASE}/drivers/adc)

zephyr_library_sources_ifdef(CONFIG_ADC_ADS8329 adc_ads8329.c)
