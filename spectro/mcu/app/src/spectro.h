
#ifndef SPECTRO_H__
#define SPECTRO_H__

#include <zephyr/kernel.h>

typedef void (*spectro_data_rdy_cb)(void *user_arg);

/**
 * @brief Sample from the spectrometer
 *
 * @param cb Callback to be invoked when data is ready
 * @param user_arg Argument passed to callback
 * @return int
 */
int spectro_sample(spectro_data_rdy_cb cb, void *user_arg);

/**
 * @brief Read a chunk of the most recent sample into @p buf
 *
 * @param buf
 * @param size
 * @param real_size Actual size read into @p buf
 * @return int
 * @retval 0 Readout complete
 * @retval 1 More data available
 * @retval <0 Error occured
 */
int spectro_stream_read(void *buf, size_t size, size_t *real_size);

#endif /* SPECTRO_H__ */
