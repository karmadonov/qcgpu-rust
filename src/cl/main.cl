typedef float2 complex_f;

/*
 * Addition of two complex numbers:
 *
 * a + b = (Re(a) + Re(b)) + i(Im(a) + Im(b))
 */
complex_f add(complex_f a, complex_f b) {
    return (complex_f)(a.x + b.x, a.y + b.y);
}

/*
 * Multiplication of two complex numbers:
 *
 * a * b =
 *   ((Re(a) * Re(b)) - (Im(a) * Im(b)))
 * + ((Im(a) * Re(b)) + (Re(a) * Im(b)))i
 */
complex_f mul(complex_f a, complex_f b) {
    return (complex_f)(
      (a.x * b.x) - (a.y * b.y),
      (a.y * b.x) + (a.x * b.y)
    );
}
/**
 * Absolute value of a complex number
 *
 * |a| = √(Re(a)^2 + Im(a)^2)
 */
float complex_abs(complex_f a) {
    return sqrt((a.x * a.x) + (a.y * a.y));
}

/*
 * Applies a single qubit gate to the register.
 * The gate matrix must be given in the form:
 *
 *  A B
 *  C D
 */
__kernel void apply_gate(
  __global complex_f* const amplitudes,
  __global complex_f* amps,
  uint target,
  complex_f A,
  complex_f B,
  complex_f C,
  complex_f D
) {
  uint const state = get_global_id(0);
  complex_f const amp = amplitudes[state];

  uint const zero_state = state & (~(1 << target));
  uint const one_state = state | (1 << target);

  uint const bit_val = (((1 << target) & state) > 0)? 1 : 0;

  if (bit_val == 0) {
    // Bitval = 0

    amps[state] = add(mul(A, amp), mul(B, amplitudes[one_state]));
  } else {
    amps[state] = add(mul(D, amp), mul(C, amplitudes[zero_state]));
  }
}

/*
 * Applies a controlled single qubit gate to the register.
 */
__kernel void apply_controlled_gate(
  __global complex_f* const amplitudes,
  __global complex_f* amps,
  uint control,
  uint target,
  complex_f A,
  complex_f B,
  complex_f C,
  complex_f D
) {
  uint const state = get_global_id(0);
  complex_f const amp = amplitudes[state];

  uint const zero_state = state & (~(1 << target));
  uint const one_state = state | (1 << target);

  uint const bit_val = (((1 << target) & state) > 0)? 1 : 0;
  uint const control_val = (((1 << control) & state) > 0)? 1 : 0;

  if (control_val == 0) {
    // Control is 0, don't apply gate
    amps[state] = amp;
  } else {
    // control is 1, apply gate.
    if (bit_val == 0) {
        // Bitval = 0
        amps[state] = add(mul(A, amp), mul(B, amplitudes[one_state]));
    } else {
        amps[state] = add(mul(D, amp), mul(C, amplitudes[zero_state]));
    }
  }
}

/*
 * Swaps the states of two qubits in the register
 */
__kernel void swap(
  __global complex_f* const amplitudes,
  __global complex_f* amps,
  uint first_qubit,
  uint second_qubit
) {
    uint const state = get_global_id(0);

    uint const first_bit_mask = 1 << first_qubit;
    uint const second_bit_mask = 1 << second_qubit;

    uint const new_second_bit = ((state & first_bit_mask) >> first_qubit) << second_qubit;
    uint const new_first_bit = ((state & second_bit_mask) >> second_qubit) << first_qubit;

    uint const new_state = (state & !first_bit_mask & !second_bit_mask) | new_first_bit | new_second_bit;

    amps[new_state] = amplitudes[state];
}

/**
 * Calculates The Probabilities Of A State Vector
 */
__kernel void calculate_probabilities(
  __global complex_f* const amplitudes,
  __global float* probabilities
) {
  uint const state = get_global_id(0);
  complex_f amp = amplitudes[state];

  probabilities[state] = complex_abs(mul(amp, amp));
}
