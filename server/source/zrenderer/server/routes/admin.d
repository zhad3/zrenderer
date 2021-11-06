module zrenderer.server.routes.admin;

import vibe.data.json;
import vibe.http.server : HTTPServerRequest, HTTPServerResponse;
import vibe.http.status;
import zrenderer.server.auth : AccessToken, checkAuth;
import zrenderer.server.globals : accessTokens;
import zrenderer.server.routes : setErrorResponse;

private void unauthorized(HTTPServerResponse res)
{
    setErrorResponse(res, HTTPStatus.unauthorized, "Unauthorized");
}

void getAccessTokens(HTTPServerRequest req, HTTPServerResponse res) @trusted
{
    immutable accessToken = checkAuth(req, accessTokens);
    if (!accessToken.isAdmin)
    {
        unauthorized(res);
        return;
    }

    import std.algorithm.iteration : filter, map;
    import std.range : tee;
    import std.array : array;

    res.writeJsonBody(accessTokens
            .byValue()
            .map!((token) {
                auto t = serializeToJson(token);
                t.remove("isValid");
                return t;
            })
            .array);
}

