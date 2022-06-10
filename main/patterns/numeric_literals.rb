# frozen_string_literal: true
require 'ruby_grammar_builder'
require 'walk_up'
require_relative walk_up_until("paths.rb")



export = Grammar.new_exportable_grammar
export.external_repos = [ # patterns that are imported
]
export.exports = [ # patterns that are exported
    :numeric_literals,
]




# 
# bet you didn't think number literals were this complicated lol
# 
def generateNumericLiteral()
    separator = "_"
    valid_single_character = /(?:[0-9a-zA-Z_\.])/
    valid_after_exponent = lookBehindFor(/[eEpP]/).then(/[+-]/)
    valid_character = Pattern.new(valid_single_character).or(valid_after_exponent)
    end_pattern = @end_of_line
    
    number_separator_pattern = Pattern.new(
        match: lookBehindFor(/[0-9a-fA-F]/).then(/#{separator}/).lookAheadFor(/[0-9a-fA-F]/),
        tag_as:"punctuation.separator.constant.numeric",
    )

    hex_digits = Pattern.new(
        match: Pattern.new(/[0-9a-fA-F]/).zeroOrMoreOf(Pattern.new(/[0-9a-fA-F]/).or(number_separator_pattern)),
        tag_as: "constant.numeric.hexadecimal",
        includes: [ number_separator_pattern ],
    )
    decimal_digits = Pattern.new(
        match: Pattern.new(/[0-9]/).zeroOrMoreOf(Pattern.new(/[0-9]/).or(number_separator_pattern)),
        tag_as: "constant.numeric.decimal",
        includes: [ number_separator_pattern ],
    )
    octal_digits = Pattern.new(
        match: oneOrMoreOf(/[0-7]/).or(number_separator_pattern),
        tag_as: "constant.numeric.octal",
        includes: [ number_separator_pattern ],
    )
    binary_digits = Pattern.new(
        match: Pattern.new(/[01]/).zeroOrMoreOf(Pattern.new(/[01]/).or(number_separator_pattern)),
        tag_as: "constant.numeric.binary",
        includes: [ number_separator_pattern ],
    )

    hex_prefix = Pattern.new(
        match: Pattern.new(/\G/).then(/0[xX]/),
        tag_as: "keyword.other.unit.hexadecimal",
    )
    octal_prefix = Pattern.new(
        # The anchor \G matches at the position where the previous match ended.
        match: Pattern.new(/\G/).then(/0/).maybe(/[oO]/),
        tag_as: "keyword.other.unit.octal",
    )
    binary_prefix = Pattern.new(
        match: Pattern.new(/\G/).then(/0[bB]/),
        tag_as: "keyword.other.unit.binary",
    )
    decimal_prefix = Pattern.new(
        match: Pattern.new(/\G/).lookAheadFor(/[0-9.]/).lookAheadToAvoid(/0[xXbBoO]/),
    )

    imaginary_suffix = Pattern.new(
        match: Pattern.new(/i/).lookAheadToAvoid(/\w/),
        tag_as:"keyword.other.unit.imaginary",
    )

    hex_exponent = Pattern.new(
        lookBehindToAvoid(/#{separator}/).then(
            match: /[pP]/,
            tag_as: "keyword.other.unit.exponent.hexadecimal",
        ).maybe(
            match: /\+/,
            tag_as: "keyword.operator.plus.exponent.hexadecimal",
        ).maybe(
            match: /\-/,
            tag_as: "keyword.operator.minus.exponent.hexadecimal",
        ).then(
            match: decimal_digits,
            tag_as: "constant.numeric.exponent.hexadecimal",
            includes: [ number_separator_pattern ]
        ),
    )
    decimal_exponent = Pattern.new(
        lookBehindToAvoid(/#{separator}/).then(
            match: /[eE]/,
            tag_as: "keyword.other.unit.exponent.decimal",
        ).maybe(
            match: /\+/,
            tag_as: "keyword.operator.plus.exponent.decimal",
        ).maybe(
            match: /\-/,
            tag_as: "keyword.operator.minus.exponent.decimal",
        ).then(
            match: decimal_digits,
            tag_as: "constant.numeric.exponent.decimal",
            includes: [ number_separator_pattern ]
        )
    )
    hex_point = Pattern.new(
        # lookBehind/Ahead because there needs to be a hex digit on at least one side
        match: lookBehindFor(/[0-9a-fA-F]/).then(/\./).or(Pattern.new(/\./).lookAheadFor(/[0-9a-fA-F]/)),
        tag_as: "constant.numeric.hexadecimal",
    )
    decimal_point = Pattern.new(
        # lookBehind/Ahead because there needs to be a decimal digit on at least one side
        match: lookBehindFor(/[0-9]/).then(/\./).or(Pattern.new(/\./).lookAheadFor(/[0-9]/)),
        tag_as: "constant.numeric.decimal.point",
    )

    hex_ending = end_pattern
    decimal_ending = end_pattern
    binary_ending = end_pattern
    octal_ending = end_pattern

    # decimal_lit    = "0" | ( "1" … "9" ) [ [ "_" ] decimal_digits ]
    decimal_lit = decimal_prefix.then(decimal_digits).maybe(imaginary_suffix).then(decimal_ending)                   
    # binary_lit     = "0" ( "b" | "B" ) [ "_" ] binary_digits
    binary_lit  = binary_prefix.maybe(/#{separator}/).then(binary_digits).maybe(imaginary_suffix).then(binary_ending)                    
    # octal_lit      = "0" [ "o" | "O" ] [ "_" ] octal_digits
    octal_lit   = octal_prefix.maybe(/#{separator}/).then(octal_digits).maybe(imaginary_suffix).then(octal_ending)                    
    # hex_lit        = "0" ( "x" | "X" ) [ "_" ] hex_digits
    hex_lit     = hex_prefix.maybe(/#{separator}/).then(hex_digits).maybe(imaginary_suffix).then(hex_ending)

    # int_lit = decimal_lit | binary_lit | octal_lit | hex_lit
    int_lit = Pattern.new(
        match: decimal_lit.or(binary_lit).or(octal_lit).or(hex_lit),
        should_not_fully_match: ["_42", "42_", "4__2", "0_xBadFace"],
        should_fully_match: [
            "42",
            "4_2",
            "0600",
            "0_600",
            "0o600",
            "0O600",
            "0xBadFace",
            "0xBad_Face",
            "0x_67_7a_2f_cc_40_c6",
            "170141183460469231731687303715884105727",
            "170_141183_460469_231731_687303_715884_105727",
        ],
    )

    # float_lit         = decimal_float_lit | hex_float_lit

    # decimal_float_lit = decimal_digits "." [ decimal_digits ] [ decimal_exponent ] |
    #                     decimal_digits decimal_exponent |
    #                     "." decimal_digits [ decimal_exponent ] .
    decimal_float_lit1 = decimal_prefix.then(decimal_digits).then(decimal_point).maybe(decimal_digits).maybe(decimal_exponent).maybe(imaginary_suffix).then(decimal_ending)
    decimal_float_lit2 = decimal_prefix.then(decimal_digits)                                          .then( decimal_exponent).maybe(imaginary_suffix).then(decimal_ending)
    decimal_float_lit3 =                   Pattern.new(/\G/).then(decimal_point).then( decimal_digits).maybe(decimal_exponent).maybe(imaginary_suffix).then(decimal_ending)

    # hex_float_lit     = "0" ( "x" | "X" ) hex_mantissa hex_exponent .
    # hex_mantissa      = [ "_" ] hex_digits "." [ hex_digits ] |
    #                     [ "_" ] hex_digits |
    #                     "." hex_digits .
    hex_float_lit1 = hex_prefix.maybe(/#{separator}/).then(hex_digits).then(hex_point).maybe(hex_digits).then(hex_exponent).maybe(imaginary_suffix).then(hex_ending)
    hex_float_lit2 = hex_prefix.maybe(/#{separator}/).then(hex_digits)                                  .then(hex_exponent).maybe(imaginary_suffix).then(hex_ending)
    hex_float_lit3 = hex_prefix                                       .then(hex_point).then( hex_digits).then(hex_exponent).maybe(imaginary_suffix).then(hex_ending)

    float_lit = Pattern.new(
        match: decimal_float_lit1.or(decimal_float_lit2).or(decimal_float_lit3).or(hex_float_lit1).or(hex_float_lit2).or(hex_float_lit3),
        should_not_fully_match: [ "0x.p1", "1p-2", "0x1.6e-2", "1_.5", "1._5", "1.5_e1", "1.5e_1", "1.5e1_", "0x15e-2" ],
        should_fully_match: [
            "0.",
            "72.40", 
            "072.40", 
            "2.71828", 
            "1.e+0", 
            "6.67428e-11", 
            ".25", 
            ".12345E+5", 
            "1_5.", 
            "0.15e+0_2",
            "0x1p-2", 
            "0x2.p10", 
            "0x1.Fp+0", 
            "0X.8p-0", 
            "0X_1FFFP-16",
        ],            
    )

    # How this works
    # (Adopted from github.com/jeff-hykin/cpp-textmate-grammar/blob/6b97d769ecc2dba2b1d4fb358e2ed6988f13c6a0/shared_patterns/numeric.rb)
    # first a range (the whole number) is found
    # then, after the range is found, it starts to figure out what kind of number/constant it is
    # it does this by matching one of the includes
    return Pattern.new(
        match: lookBehindToAvoid(/\w/).then(/\.?\d/).zeroOrMoreOf(valid_character),
        includes: [
            # NOTE: this PatternRange.new should be redundant, it makes no sense
            #       thats because there's a desireable edgecase behavior we want
            #       \G (as used above) matches the begining of the Range, and it only
            #       works for Ranges. So we find a pattern, then capture everything 
            #       inside that pattern with a range so that the begining of the pattern can be matched
            PatternRange.new(
                start_pattern: lookAheadFor(/./),
                end_pattern: end_pattern,
                # only a single include pattern should match
                includes: [
                    float_lit,
                    int_lit,
                    # imaginary_lit = (decimal_digits | int_lit | float_lit) "i" .
                    #  : imaginary number handling was combined with other *_lit rules by checking `maybe(imaginary_suffix)` before ending.

                    # invalid
                    Pattern.new(
                        match: oneOrMoreOf(Pattern.new(valid_single_character).or(valid_after_exponent)),
                        tag_as: "invalid.illegal.constant.numeric"
                    ),
                ]
            ),
        ],
    )
end

# create/export the numeric literal
export[:numeric_literals] = generateNumericLiteral()