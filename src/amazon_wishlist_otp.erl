%%%%-------------------------------------------------------------------
%%% File    : amazon_wishlist_otp.erl
%%% Author  : Joe Williams
%%% Description : Converted my amazon wishlist app to use gen_server
%%%
%%% Created : 20090107
%%%-------------------------------------------------------------------

-module(amazon_wishlist_otp).

-behaviour(gen_server).

-define(SERVER, ?MODULE).

-include_lib("xmerl/include/xmerl.hrl").

-define(LIST_ID_URL,
		"http://webservices.amazon.com/onca/xml?"
		"Service=AWSECommerceService&Operation=ListSearch"
		"&SubscriptionId=08XDXR9RWBWD570R0102&"
		"&ListType=WishList"
		"&Email=").

-define(LIST_URL,
		"http://webservices.amazon.com/onca/xml?"
		"Service=AWSECommerceService&Operation=ListLookup"
		"&SubscriptionId=08XDXR9RWBWD570R0102"
		"&ListType=WishList"
		"&ResponseGroup=ListItems"
		"&ListId=").

-define(Val(X),
   (fun() ->
            [ V || #xmlElement{ content = [#xmlText{value = V}|_]} <- X]
    end)()).

%% API
-export([start_link/0,get_wishlist/1]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
	 terminate/2, code_change/3]).

-record(state, {}).

%%====================================================================
%% API
%%====================================================================
%%--------------------------------------------------------------------
%% Function: start_link() -> {ok,Pid} | ignore | {error,Error}
%% Description: Starts the server
%%--------------------------------------------------------------------
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []),
    inets:start().

%%====================================================================
%% gen_server callbacks
%%====================================================================

%%--------------------------------------------------------------------
%% Function: init(Args) -> {ok, State} |
%%                         {ok, State, Timeout} |
%%                         ignore               |
%%                         {stop, Reason}
%% Description: Initiates the server
%%--------------------------------------------------------------------
init([]) ->
    {ok, #state{}}.

%%--------------------------------------------------------------------
%% Function: %% handle_call(Request, From, State) -> {reply, Reply, State} |
%%                                      {reply, Reply, State, Timeout} |
%%                                      {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, Reply, State} |
%%                                      {stop, Reason, State}
%% Description: Handling call messages
%%--------------------------------------------------------------------
handle_call({get_wishlist, Email_addr}, _From, State) ->
	%% Frist built the URL for your account and make a request
	List_id_url = ?LIST_ID_URL ++ Email_addr,
	{ ok, { _Status, _Headers, Body }} = http:request(List_id_url),
	%% This checks the server status
	check_status(_Status),
	%% Parse the XML to get your wishlist IDs
	{ Xml, _Rest } = xmerl_scan:string(Body),
	List_id = ?Val(xmerl_xpath:string("//ListId", Xml)),
	%% Build the wishlist URL and make a request
	List_url = ?LIST_URL ++ List_id,
	{ ok, { _Status1, _Headers1, Body1 }} = http:request(List_url),
	check_status(_Status1),
	%% Parse the XML to get the names of the items
	{ Xml1, _Rest1 } = xmerl_scan:string(Body1),
	Titles = ?Val(xmerl_xpath:string("//Title", Xml1)),
	%Reply back with the list of titles
	Reply = [ [T] || T <- Titles ],
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% Function: handle_cast(Msg, State) -> {noreply, State} |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, State}
%% Description: Handling cast messages
%%--------------------------------------------------------------------
handle_cast(_Msg, State) ->
    {noreply, State}.
    
%%--------------------------------------------------------------------
%% Function: handle_info(Info, State) -> {noreply, State} |
%%                                       {noreply, State, Timeout} |
%%                                       {stop, Reason, State}
%% Description: Handling all non call/cast messages
%%--------------------------------------------------------------------
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% Function: terminate(Reason, State) -> void()
%% Description: This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any necessary
%% cleaning up. When it returns, the gen_server terminates with Reason.
%% The return value is ignored.
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% Func: code_change(OldVsn, State, Extra) -> {ok, NewState}
%% Description: Convert process state when code is changed
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%--------------------------------------------------------------------
%%% Internal functions
%%--------------------------------------------------------------------


check_status(_Status) ->
	case _Status of
		{"HTTP/1.1",200,"OK"} ->
			ok;
		_ ->
			io:format("Error! Bad Status Code. ~p ~n", [_Status]),
			exit(not_200_status_code)
	end.
	
get_wishlist(Email_addr) ->
	gen_server:call(?MODULE, {get_wishlist, Email_addr}).

