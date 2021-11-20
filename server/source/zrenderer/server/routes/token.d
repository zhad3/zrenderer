module zrenderer.server.routes.token;

import vibe.data.json;
import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
import zrenderer.server.auth : AccessToken, checkAuth;
import zrenderer.server.globals : accessTokens;
import zrenderer.server.routes : unauthorized;

void getAccessTokenInfo(HTTPServerRequest req, HTTPServerResponse res) @trusted
{
    immutable accessToken = checkAuth(req, accessTokens);
    if (accessToken.isNull())
    {
        unauthorized(res);
        return;
    }

    auto jsonToken = Json(["capabilities": serializeToJson(accessToken.get.capabilities),
                "properties": serializeToJson(accessToken.get.properties)]);

    res.writeJsonBody(jsonToken);
}

