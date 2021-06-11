// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0 OR MIT

use crate::gotoc::GotocCtx;
use crate::gotoc::Stmt;
use rustc_hir::def_id::DefId;
use rustc_middle::mir::BasicBlock;
use rustc_middle::mir::Body;
use rustc_middle::ty::Instance;
use rustc_middle::ty::PolyFnSig;
use rustc_middle::ty::TyCtxt;

/// This structure represents useful data about the function we are currently compiling.
pub struct CurrentFnCtx<'tcx> {
    /// The GOTO block we are compiling into
    block: Vec<Stmt>,
    /// The current MIR basic block
    current_bb: Option<BasicBlock>,
    /// The codegen instance for the current function
    instance: Instance<'tcx>,
    /// The goto labels for all blocks
    labels: Vec<String>,
    /// The mir for the current instance
    mir: &'tcx Body<'tcx>,
    /// The symbol name of the current function
    name: String,
    /// The signature of the current function
    sig: PolyFnSig<'tcx>,
    /// A counter to enable creating temporary variables
    temp_var_counter: u64,
}

/// Constructor
impl CurrentFnCtx<'tcx> {
    pub fn new(instance: Instance<'tcx>, gcx: &GotocCtx<'tcx>) -> Self {
        Self {
            block: vec![],
            current_bb: None,
            instance,
            labels: vec![],
            mir: gcx.tcx.instance_mir(instance.def),
            name: gcx.symbol_name(instance),
            sig: gcx.fn_sig_of_instance(instance),
            temp_var_counter: 0,
        }
    }
}

/// Setters
impl CurrentFnCtx<'tcx> {
    /// Returns the current block, replacing it with an empty vector.
    pub fn extract_block(&mut self) -> Vec<Stmt> {
        std::mem::replace(&mut self.block, vec![])
    }

    pub fn get_and_incr_counter(&mut self) -> u64 {
        let rval = self.temp_var_counter;
        self.temp_var_counter += 1;
        rval
    }

    pub fn push_onto_block(&mut self, s: Stmt) {
        self.block.push(s)
    }

    pub fn reset_current_bb(&mut self) {
        self.current_bb = None;
    }

    pub fn set_current_bb(&mut self, bb: BasicBlock) {
        self.current_bb = Some(bb);
    }

    pub fn set_labels(&mut self, labels: Vec<String>) {
        assert!(self.labels.is_empty());
        self.labels = labels;
    }
}

/// Getters
impl CurrentFnCtx<'tcx> {
    /// The basic block we are currently compiling
    pub fn current_bb(&self) -> BasicBlock {
        self.current_bb.unwrap()
    }

    /// The function we are currently compiling
    pub fn instance(&self) -> Instance<'tcx> {
        self.instance
    }

    /// The labels in the function we are currently compiling
    pub fn labels(&self) -> &Vec<String> {
        &self.labels
    }

    /// The MIR for the function we are currently compiling
    pub fn mir(&self) -> &'tcx Body<'tcx> {
        self.mir
    }

    /// The name of the function we are currently compiling
    pub fn name(&self) -> String {
        self.name.clone()
    }

    /// The signature of the function we are currently compiling
    pub fn sig(&self) -> PolyFnSig<'tcx> {
        self.sig
    }
}

/// Utility functions
impl CurrentFnCtx<'_> {
    pub fn find_label(&self, bb: &BasicBlock) -> String {
        self.labels[bb.index()].clone()
    }
}
