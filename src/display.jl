
const global_application = Ref{Application}()


struct DisplayInline
    dom_function
end


"""
    with_session(f)::DisplayInline

calls f with the session, that will become active when displaying the result
of with_session. f is expected to return a valid DOM.
"""
function with_session(f)
    return DisplayInline(f)
end

const WebMimes = (
    MIME"text/html",
    MIME"application/prs.juno.plotpane+html",
    # MIME"application/vnd.webio.application+html"
)

function get_global_app()
    if !isassigned(global_application) || istaskdone(global_application[].server_task[])
        global_application[] = Application(
            (ctx, request)-> "Nothing to see",
            get(ENV, "WEBIO_SERVER_HOST_URL", "127.0.0.1"),
            parse(Int, get(ENV, "WEBIO_HTTP_PORT", "8081")),
            verbose = get(ENV, "JSCALL_VERBOSITY_LEVEL", "false") == "true"
        )
    end
    global_application[]
end

for M in WebMimes
    @eval function Base.show(io::IO, m::$M, dom::DisplayInline)
        application = get_global_app()
        session_url = "/show"
        route!(application, session_url) do context
            # Serve the actual content
            return serve_dom(context, dom.dom_function)
        end
        # Display the route we just added in an iframe inline:
        url = repr(local_url(application, session_url))
        println(io, "<iframe src=$(url) style=\"position: absolute; height: 100%; border: none\">")
        println(io, "</iframe>")
    end
end

function Base.show(io::IO, m::MIME"application/vnd.webio.application+html", dom::DisplayInline)
    application = get_global_app()
    session = Session()
    application.sessions[session.id] = Dict("base" => session)
    dom = Base.invokelatest(dom.dom_function, session, (target = "/show",))
    dom2html(io, session, session.id, dom)
end
