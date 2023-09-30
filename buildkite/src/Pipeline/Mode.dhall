-- Mode defines pipeline goal
--
-- Goal of the pipeline can be either quick feedback for CI changes
-- or Nightly run which supposed to be run only on stable changes.

let Prelude = ../External/Prelude.dhall

let Mode = < PullRequest | Stable | Nightly >

let capitalName = \(pipelineMode : Mode) ->
  merge {
    PullRequest = "PullRequest"
    , Stable = "Stable"
    , Nightly = "Nightly"
  } pipelineMode

let channel = \(pipelineMode: Mode) -> 
  merge {
    PullRequest = "unstable"
    , Stable = "stable"
    , Nightly = "nightly"
  } pipelineMode
in
{ 
    Type = Mode,
    channel = channel,
    capitalName = capitalName
}