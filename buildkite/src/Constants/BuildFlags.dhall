let Prelude = ../External/Prelude.dhall

let BuildFlags : Type = < Standard | Instrumented >

let capitalName = \(buildFlag : BuildFlag) ->
  merge {
    Standard = "Standard"
    , Instrumented = "Instrumented"
  } buildFlag

let lowerName = \(buildFlag : BuildFlag) ->
  merge {
    Standard = "standard"
    , Instrumented = "instrumented"
  } buildFlag

let buildEnvs = \(buildFlag : BuildFlag) ->
  merge {
    Standard = []
    , Instrumented = ["DUNE_INSTRUMENT_WITH=bisect_ppx"]
  } buildFlag

let toSuffixUppercase = \(buildFlag : BuildFlag) ->
  merge {
    Standard = ""
    , Instrumented = "Instrumented"
  } buildFlag

let toSuffixLowercase = \(buildFlag : BuildFlag) ->
  merge {
    Standard = ""
    , Instrumented = "instrumented"
  } buildFlag

let toLabelSegment = \(buildFlag : BuildFlag) ->
  merge {
    Standard = ""
    , Instrumented = "-instrumented"
  } buildFlag



in

{
  Type = BuildFlag
  , capitalName = capitalName
  , lowerName = lowerName
  , duneBuildFlag = duneBuildFlag
  , toSuffixUppercase = toSuffixUppercase
  , toSuffixLowercase = toSuffixLowercase
  , toLabelSegment = toLabelSegment
}
