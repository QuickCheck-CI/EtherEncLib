%%% @author Thomas Arts
%%% @copyright (C) 2014, Quviq AB
%%%      This QuickCheck test module may be used free of charge to test your implementation
%%%      In order to do so, add this file to your repository and register your github project at quickcheck-ci.com 
%%%  
%%% @doc In RFC 1071 efficient algorithms are discussed for computing the internet checksum, also known as IP checksum. 
%%%      Whenever you implement efficient algorithms, an error may sneak through. 
%%%      This module implements a QuickCheck property (www.quviq.com) for testing checksum implementations in C.
%%%    
%%%
%%% @end
%%% Created : 22 Oct 2014 by Thomas Arts

-module(checksum_eqc).

-include_lib("eqc/include/eqc.hrl").
-compile(export_all).

%% The name of the C program under test
%% Consult the manual if the C program depends on header files not in present directory
-define(C_PROGRAM,"checksum.c").

%% Adapt the code below
%% The tests produce a binary, we need to store it in C memory with right type
%% Calling the C function depends on your implementation
c_checksum(Bin) ->
  Buf = eqc_c:create_array("uint8_t", binary_to_list(Bin)),
  Sum = c_call:checksum(Buf, size(Buf), 0),
  <<Sum:16>>.


%% Test C implementation against itself
%% Generate a random binary of max 2048 bytes
%% Add the checksum field as first word cleared with 0.
%% Compute the checksum Sum and once more with Sum in checksum field.
%% Result should be zero.
prop_verify() ->
  ?SETUP(fun() -> 
	     eqc_c:start(c_call,[{c_src,?C_PROGRAM}]),
	     fun() -> ok end
	 end,
	 ?FORALL(N, choose(0,2048),
		 ?FORALL(Bin, binary(N),
			 begin
			   Sum = c_checksum(<<0:16,Bin/binary>>),
			   equals(c_checksum(<<Sum/binary, Bin/binary>>), <<0:16>>)
			 end))).


%% Check against a reference implementation
prop_reference() ->
  ?SETUP(fun() -> 
	     eqc_c:start(c_call,[{c_src,?C_PROGRAM}]),
	     fun() -> ok end
	 end,
	 ?FORALL(N, choose(0,1024),
		 ?FORALL(Bin, binary(N),
			 begin
			   equals(c_checksum(Bin), checksum(Bin))
			 end))).



%% Reference implementation in Erlang
checksum(Bin) ->
  negate(sum(pad(Bin))).


%% Padding with a byte at the end in case uneven number of bytes
pad(Binary) ->
    PaddingLength = (size(Binary) rem 2)*8,
    <<Binary/binary, 0:PaddingLength>>.

% Sum a binary of words in ones complement representation.
sum(Bin) when size(Bin) rem 2 == 0 ->
  Sum = lists:foldl(fun(A, B) -> A+B end, 0, [ Word || <<Word:16>> <= Bin ]),
  case Sum > 16#ffff of
    true -> sum(<<Sum:1024>>);
    false -> <<Sum:16>>
  end.

%% invert all bits... as simple as that.
negate(BitString) ->
    << <<(1-Bit):1>> || <<Bit:1>> <= BitString >>.


