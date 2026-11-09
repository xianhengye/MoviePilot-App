import Testing

@testable import MoviePilotCore

struct ShellDevicePolicyTests {
  @Test func onlyConfirmedDuoModelOptsIn() {
    #expect(ShellDevicePolicy.usesDuoInterface(modelIdentifier: "iPhone19,4"))
  }

  @Test func ordinaryAndUnknownDevicesKeepUpstreamShell() {
    for model in [
      "iPhone19,1", "iPhone19,2", "iPhone19,3", "iPhone19,5", "iPhone18,2",
      "iPad17,2", "arm64", "x86_64", "", "unknown", "iPhone20,4", "iPhone19,40",
    ] {
      #expect(!ShellDevicePolicy.usesDuoInterface(modelIdentifier: model))
    }
  }
}
