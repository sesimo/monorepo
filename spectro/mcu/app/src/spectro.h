
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

/**
 * @brief Get current integration time
 *
 * @return uint32_t Integration time in microseconds
 */
uint32_t spectro_get_int_time(void);

/**
 * @brief Set integration time
 *
 * @param int_us Integration time in microseconds
 * @return int
 * @retval 0 Success
 * @retval <0 Negative errno code
 */
int spectro_set_int_time(uint32_t int_us);

/**
 * @brief Set ctrl parameters for pipeline
 *
 * The arguments @p dc, @p totavg and @p movavg control whether or not the
 * respective pipeline stage is skipped or not.
 *
 * @param dc false to skip dark current stage, true if not
 * @param totavg false to skip total average stage, true if not
 * @param movavg false to skip movavg stage, true if not
 * @return int
 * @retval 0 Success
 * @retval <0 Negative errno code
 */
int spectro_set_pipeline_ctrl(uint8_t dc, uint8_t totavg, uint8_t movavg);

#endif /* SPECTRO_H__ */
