import Testing

@testable import IAGOEngine

/// ADR-0069: what the engine does depends on the RAM of the Mac.
@Suite struct EnginePolicyTests {
    let qwen4 = EngineCatalog.model("qwen3.5-4b")!
    let qwen9 = EngineCatalog.model("qwen3.5-9b")!
    let gemma = EngineCatalog.model("gemma-4-12b")!

    @Test func automaticWorkIsOnByDefaultOnlyWithRoomToSpare() {
        #expect(!EnginePolicy.automaticWorkByDefault(ramGB: 8))
        #expect(!EnginePolicy.automaticWorkByDefault(ramGB: 16))
        #expect(!EnginePolicy.automaticWorkByDefault(ramGB: 24))
        #expect(EnginePolicy.automaticWorkByDefault(ramGB: 32))
        #expect(EnginePolicy.automaticWorkByDefault(ramGB: 64))
        #expect(EnginePolicy.freesModelAfterBackgroundWork(ramGB: 16))
        #expect(!EnginePolicy.freesModelAfterBackgroundWork(ramGB: 32))
        #expect(!EnginePolicy.chatDuringTranscription(ramGB: 16))
        #expect(EnginePolicy.chatDuringTranscription(ramGB: 36))
        #expect(EnginePolicy.cacheLimitBytes(ramGB: 16) < EnginePolicy.cacheLimitBytes(ramGB: 32))
    }

    @Test func gemmaIsNotForSmallMacs() {
        #expect(!EnginePolicy.fits(gemma, ramGB: 16))
        #expect(EnginePolicy.fits(gemma, ramGB: 24))
        #expect(EnginePolicy.fits(qwen9, ramGB: 16))
        #expect(EnginePolicy.fits(qwen4, ramGB: 8))
        // The recommended model always fits.
        for ram in [8, 16, 18, 24, 32, 64] {
            #expect(EnginePolicy.fits(EngineCatalog.recommended(forRAMGB: ram), ramGB: ram))
        }
    }

    @Test func aModelThatDoesNotFitIsReplacedByTheBiggestThatDoes() {
        let installed = [qwen4, qwen9, gemma]
        #expect(EnginePolicy.replacement(for: gemma, installed: installed, ramGB: 16) == qwen9)
        #expect(EnginePolicy.replacement(for: gemma, installed: [gemma, qwen4], ramGB: 16) == qwen4)
        #expect(EnginePolicy.replacement(for: gemma, installed: [gemma], ramGB: 16) == nil)
        #expect(EnginePolicy.replacement(for: gemma, installed: installed, ramGB: 32) == nil)
        #expect(EnginePolicy.replacement(for: qwen9, installed: installed, ramGB: 16) == nil)
    }
}
