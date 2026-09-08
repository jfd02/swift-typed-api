import protocol ArgumentParser.ExpressibleByArgument
import struct ConfigurationParser.OptionOverride

extension OptionOverride: @retroactive ExpressibleByArgument {
    public init?(argument: String) {
        self.init(argument)
    }
}
