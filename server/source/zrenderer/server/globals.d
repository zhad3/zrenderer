module zrenderer.server.globals;

import config : Config;
import zrenderer.server.auth : AccessToken;

__gshared Config defaultConfig;
__gshared AccessToken[string] accessTokens;

