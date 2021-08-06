module zrenderer.server.responsedata;

struct RenderResponseData
{
    /// Contains one or more paths to the rendered sprites.
    immutable(string)[] output;
}
