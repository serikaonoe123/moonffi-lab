// Copyright 2026 International Digital Economy Academy
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

///| The historical fixture stream from core 0.10.15. This intentionally keeps
/// its mixing/gamma formulas, including behavior corrected upstream in 0.10.16.
/// It preserves generator_version provenance; it is not a general RNG API.
pub struct RandomState {
  priv mut seed : UInt64
  priv gamma : UInt64
}

///|
pub fn RandomState::RandomState(seed~ : UInt64) -> RandomState {
  { seed: mix(seed), gamma: gamma(seed + 0x9e3779b97f4a7c15UL) }
}

///|
fn mix(value : UInt64) -> UInt64 {
  let first = (value ^ (value >> 30)) * 0xff51afd7ed558ccdUL
  let second = (first ^ (first >> 33)) * 0xc4ceb9fe1a85ec53UL
  second ^ (second >> 33)
}

///|
fn gamma(value : UInt64) -> UInt64 {
  let value = value | 1UL
  let first = (value ^ (value >> 30)) * 0xbf58476d1ce4e5b9UL
  let second = (first ^ (first >> 27)) * 0x94d049bb133111ebUL
  let mixed = second ^ (second >> 31)
  if (mixed | (mixed >> 1)).popcnt() >= 24 {
    mixed
  } else {
    mixed ^ 0xaaaaaaaaaaaaaaaaUL
  }
}

///|
fn RandomState::word(self : RandomState) -> UInt64 {
  self.seed += self.gamma
  mix(self.seed)
}

///| Match the old bitmask rejection and word consumption exactly.
pub fn RandomState::next_uint(self : RandomState, limit~ : UInt) -> UInt {
  guard limit > 0U else { abort("fixture random limit must be positive") }
  let bound = limit.to_uint64()
  let mask = if bound == 1UL {
    0UL
  } else {
    0xffffffffffffffffUL >> (bound - 1UL).clz()
  }
  let mut value = self.word() & mask
  while value >= bound {
    value = self.word() & mask
  }
  value.to_uint()
}
