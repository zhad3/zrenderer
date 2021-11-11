module zrenderer.server.globals;

import config : Config;
import zrenderer.server.auth : AccessToken, AccessTokenDB;

__gshared Config defaultConfig;
__gshared AccessTokenDB accessTokens;

