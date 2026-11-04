/// Explicit opt-in keeps ordinary iPhones, iPads and unknown devices on the upstream shell.
public enum ShellDevicePolicy {
  public static func usesDuoInterface(modelIdentifier: String) -> Bool {
    modelIdentifier == "iPhone19,4"
  }
}
