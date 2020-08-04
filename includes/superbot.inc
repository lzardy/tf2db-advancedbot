#if defined _superbot_included
 #endinput
#endif
#define _tfdb_superbot_included

/**
 * Check if the bot is enabled.
 *
 */
native int TFDB_botActivated();

public SharedPlugin __pl_superbot = 
{
	name = "superbot",
	file = "superbot.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_superbot_SetNTVOptional()
{
	MarkNativeAsOptional("TFDB_botActivated");
}
#endif