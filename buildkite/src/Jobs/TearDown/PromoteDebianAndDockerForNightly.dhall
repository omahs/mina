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
        mode = PipelineMode.Type.Nightly,
        name = "PromoteDebianAndDockerForNigthly"
    }
  , steps = [
      Command.build
        Command.Config::{
          commands =
            RunInToolchain.runInToolchainBullseye ["COVERALLS_TOKEN"]
              "buildkite/scripts/promote_debian_package.sh unstable nightly bullseye" && \
              "buildkite/scripts/promote_debian_package.sh unstable nightly buster" && \
              "buildkite/scripts/promote_debian_package.sh unstable nightly focal" && \
              "printf -v date '%(%Y-%m-%d)T\n' -1" && \
              "export NEW_TAG=nightly-${date}" && \
              "buildkite/scripts/retag-dockers.sh",
          label = "Promote Debian and dockers for nightly",
          key = "promote-debian-and-dockers-for-nightly",
          target = Size.Small
        }
    ]
  }