

/* cap	: capability to a resource
 * cd	: ipc handle for the resource you've opened. this is process owned
 */

/*
 * @function  ipc_open
 * @brief  open (start) an ipc with your capability
 * @param[in] cap  capability to ipc
 * @return  ipc handle
 */
cd_t ipc_open(cap_t *cap)
{
	return open(cap->file_name);
}

/*
 * @function  ipc_send
 * @brief  send a message to the ipc end point
 * @param[in] cd  handle to ipc
 * @param[in] msg  message to send
 */
void ipc_send(cd_t cd, const msg_t *msg)
{
	write(cd, msg, sizeof(*msg));
}

/*
 * @function  ipc_close
 * @brief  close an running ipc
 * @param[in] cap  capability to ipc
 * @return  ipc handle
 */
void ipc_close(cd_t cd);

/*
 * @function  ipc_recv
 * @brief  receive a message from a capability
 * @param[in] cd  handle to ipc
 * @param[out] msg  message received
 */
void ipc_recv(cd_t cd, msg_t *msg)
{
	read(cd, msg, sizeof(*msg));
}

/*
 * @function  ipc_post
 * @brief  wait for somebody serve for the capability
 * @param[in] cd  handle to ipc / capability
 */
void ipc_post(cd_t cd)
{
}

/*
 * @function  ipc_wait
 * @brief  wait for somebody requesting on the capability
 * @param[in] cd  handle to ipc / capability
 */
void ipc_wait(cd_t cd)
{
}
