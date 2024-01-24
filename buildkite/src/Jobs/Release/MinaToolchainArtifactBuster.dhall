let Prelude = ../../External/Prelude.dhall

let Cmd = ../../Lib/Cmds.dhall
let S = ../../Lib/SelectFiles.dhall

let Pipeline = ../../Pipeline/Dsl.dhall
let PipelineTag = ../../Pipeline/Tag.dhall
let PipelineMode = ../../Pipeline/Mode.dhall
let JobSpec = ../../Pipeline/JobSpec.dhall

let Command = ../../Command/Base.dhall
let Size = ../../Command/Size.dhall
let DockerImage = ../../Command/DockerImage.dhall
let DockerLogin = ../../Command/DockerLogin/Type.dhall


in

Pipeline.build
  Pipeline.Config::{
    spec =
      JobSpec::{
        dirtyWhen = [
          S.strictlyStart (S.contains "dockerfiles/stages/1-"),
          S.strictlyStart (S.contains "dockerfiles/stages/2-"),
          S.strictlyStart (S.contains "dockerfiles/stages/3-"),
          S.strictlyStart (S.contains "buildkite/src/Jobs/Release/MinaToolchainArtifact"),
          S.strictly (S.contains "opam.export"),
          -- Rust version has changed
          S.strictlyEnd (S.contains "rust-toolchain.toml")
        ],
        path = "Release",
        name = "MinaToolchainArtifactBuster",
        tags = [ PipelineTag.Type.Toolchain ],
        mode = PipelineMode.Type.Stable        
      },
    steps = [

      -- mina-toolchain Debian 10 "Buster" Toolchain
      let toolchainBusterSpec = DockerImage.ReleaseSpec::{
        service="mina-toolchain",
        deb_codename="buster",
        extra_args="--no-cache",
        step_key="toolchain-buster-docker-image"
      }

      in

      DockerImage.generateStep toolchainBusterSpec

    ]
  }