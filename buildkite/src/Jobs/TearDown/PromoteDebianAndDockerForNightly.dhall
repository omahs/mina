let Prelude =  ../../External/Prelude.dhall
let S = ../../Lib/SelectFiles.dhall
let Cmd = ../../Lib/Cmds.dhall
let RunInToolchain = ../../Command/RunInToolchain.dhall
let Command = ../../Command/Base.dhall
let Docker = ../../Command/Docker/Type.dhall
let Size = ../../Command/Size.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall
let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineMode = ../../Pipeline/Mode.dhall
let PipelineStage = ../../Pipeline/Stage.dhall

in Pipeline.build 
  Pipeline.Config::{
    spec =
      JobSpec::{
        dirtyWhen = [ S.everything ],
        path = "TearDown",
        stage = PipelineStage.Type.TearDown,
        name = "PromoteDebianAndDockerForNigthly"
    }
  , steps = [
      Command.build
        Command.Config::{
          commands =
            RunInToolchain.runInToolchainBullseye ["COVERALLS_TOKEN"]
              "buildkite/scripts/promote_debian_package.sh unstable nightly bullseye" && \
              "buildkite/scripts/promote_debian_package.sh unstable nightly buster" && \
              "buildkite/scripts/promote_debian_package.sh unstable nightly focal",
          label = "Promote Debian and dockers for nightly",
          key = "promote-debian-and-dockers-for-nightly",
          mode = PipelineMode.Nightly
          target = Size.Small
        }
    ]
  }