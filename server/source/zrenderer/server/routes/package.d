module zrenderer.server.routes;

public import zrenderer.server.routes.admin;
public import zrenderer.server.routes.render;

import vibe.data.json;
import vibe.http.server : HTTPServerResponse;
import vibe.http.status;

void setErrorResponse(ref HTTPServerResponse res, HTTPStatus httpStatus, const scope string message = string.init)
{
    res.statusCode = httpStatus;
    auto jsonResponse = Json(["statusMessage": Json(message)]);
    res.writeJsonBody(jsonResponse);
}

