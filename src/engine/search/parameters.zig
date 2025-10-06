pub var lmr_weight: f64 = 0.429;
pub var lmr_bias: f64 = 0.769;

pub var rfp_depth: i32 = 8;
pub var rfp_multiplier: i32 = 58;
pub var rfp_improving_deduction: i32 = 69;

pub var nmp_improving_margin: i32 = 72;
pub var nmp_base: usize = 3;
pub var nmp_depth_divisor: usize = 3;
pub var nmp_beta_divisor: i32 = 206;

pub var razoring_base: i32 = 68;
pub var razoring_margin: i32 = 191;

pub var aspiration_window: i32 = 11;

pub const Tunable = struct {
    name: []const u8,
    value: []const u8,
    min_value: []const u8,
    max_value: []const u8,
    id: usize,
};

pub const tunable_params = [_]Tunable{
    Tunable{ .name = "LMRWeight", .value = "429", .min_value = "1", .max_value = "999", .id = 0 },
    Tunable{ .name = "LMRBias", .value = "769", .min_value = "1", .max_value = "9999", .id = 1 },
    Tunable{ .name = "RFPDepth", .value = "8", .min_value = "1", .max_value = "16", .id = 2 },
    Tunable{ .name = "RFPMultiplier", .value = "58", .min_value = "1", .max_value = "999", .id = 3 },
    Tunable{ .name = "RFPImprovingDeduction", .value = "69", .min_value = "1", .max_value = "999", .id = 4 },
    Tunable{ .name = "NMPImprovingMargin", .value = "72", .min_value = "1", .max_value = "999", .id = 5 },
    Tunable{ .name = "NMPBase", .value = "3", .min_value = "1", .max_value = "16", .id = 6 },
    Tunable{ .name = "NMPDepthDivisor", .value = "3", .min_value = "1", .max_value = "16", .id = 7 },
    Tunable{ .name = "NMPBetaDivisor", .value = "206", .min_value = "1", .max_value = "999", .id = 8 },
    Tunable{ .name = "RazoringBase", .value = "68", .min_value = "1", .max_value = "999", .id = 9 },
    Tunable{ .name = "RazoringMargin", .value = "191", .min_value = "1", .max_value = "999", .id = 10 },
    Tunable{ .name = "AspirationWindow", .value = "11", .min_value = "1", .max_value = "999", .id = 11 },
};
