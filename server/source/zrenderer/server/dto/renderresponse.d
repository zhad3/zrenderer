module zrenderer.server.dto.renderresponse;

struct RenderResponseData
{
    /// Contains one or more paths to the rendered sprites.
    immutable(string)[] output;
}
