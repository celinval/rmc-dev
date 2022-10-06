// Copyright 2019 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0
// kani-flags: --legacy-linker
// There seems to be a an issue with drop_in_place with the MIR Linker. The odd thing is that
// running the monomorphizer with the --always-encode-mir sysroot gives us the same result.
//! Check if we can codegen drop for unsized struct.
//! MIR linker seems to be missing some drop functions.
use std::rc::Rc;

pub trait DummyTrait {}

pub struct Wrapper<T: ?Sized> {
    pub w_id: u128,
    pub inner: T,
}

impl<T: ?Sized> Drop for Wrapper<T> {
    fn drop(&mut self) {
        assert_eq!(self.w_id, 0);
    }
}

struct DummyImpl {
    pub id: u128,
}

impl DummyTrait for DummyImpl {}

impl Drop for DummyImpl {
    fn drop(&mut self) {
        assert_eq!(self.id, 1);
    }
}

#[kani::proof]
fn check_drop_dyn() {
    let original = Rc::new(Wrapper { w_id: 0, inner: DummyImpl { id: 1 } });
    let _wrapper =
        unsafe { Rc::from_raw(Rc::into_raw(original) as *const Wrapper<dyn DummyTrait>) };
}
