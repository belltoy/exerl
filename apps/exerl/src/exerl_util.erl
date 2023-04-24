-module(exerl_util).

-export([
    ensure_started/1,
    tls_opts/0,
    download_to_file/2,
    github_api/1,
    checksum_file/2
]).

-define(USER_AGENT, "exerl/0").

%% @doc Start an application and its dependencies and explicitly `error' in case
%% it can not be started.
-spec ensure_started(atom()) -> ok.
ensure_started(App) ->
    case application:ensure_all_started(App) of
        {ok, _} -> ok;
        {error, already_started} -> ok;
        {error, Error} -> error(Error)
    end.

%% @doc Return options for `ssl' functions that use the system certificate store
-spec tls_opts() -> [ssl:tls_option()].
tls_opts() ->
    try
        case erlang:function_exported(httpc, ssl_verify_host_options, 1) of
            true ->
                httpc:ssl_verify_host_options(true);
            false ->
                case erlang:function_exported(public_key, cacerts_get, 0) of
                    true ->
                        CaCerts = public_key:cacerts_get(),
                        [
                            {verify, verify_peer},
                            {cacerts, CaCerts},
                            {customize_hostname_check, [
                                {match_fun, public_key:pkix_verify_hostname_match_fun(https)}
                            ]}
                        ];
                    false ->
                        []
                end
        end
    catch
        _:{badmatch, {error, enoent}} ->
            []
    end.

download_to_file(Url, Dest) ->
    DestS = binary_to_list(list_to_binary([Dest])),
    {ok, saved_to_file} = httpc:request(
        get,
        {
            Url,
            [{"User-Agent", ?USER_AGENT}]
        },
        [{ssl, tls_opts()}],
        [{stream, DestS}]
    ),
    ok.

github_api(Path) ->
    {ok, Result} = httpc:request(
        get,
        {
            uri_string:recompose(#{
                scheme => "https",
                host => "api.github.com",
                path => Path
            }),
            [
                {"Accept", "application/vnd.github+json"},
                {"X-GitHub-Api-Version", "2022-11-28"},
                {"User-Agent", ?USER_AGENT}
            ]
        },
        [{ssl, tls_opts()}],
        [{body_format, binary}]
    ),

    {{_, 200, _}, _Headers, Body} = Result,
    {ok, Map} = thoas:decode(Body),
    Map.

checksum_file(Algorithm, Filename) ->
    F = file:open(Filename, []),
    C = crypto:hash_init(Algorithm),
    ok.