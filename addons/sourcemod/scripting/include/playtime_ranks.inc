/** Double-include prevention */
#if defined _playtime_ranks_included_
 #endinput
#endif
#define _playtime_ranks_included_

/**
 * Retrieves the current playtime of a player.
 *
 * @param client    The client.
 * @param tag		The char where the tag should get written to.
 * @param length    The max length.
 * @return        True if succesfull or false if not.
 */
native int PTR_GetClientTag(int client, char[] tag, int length);
