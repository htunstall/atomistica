#! /usr/bin/env python

# ======================================================================
# Atomistica - Interatomic potential library and molecular dynamics code
# https://github.com/Atomistica/atomistica
#
# Copyright (2005-2015) Lars Pastewka <lars.pastewka@kit.edu> and others
# See the AUTHORS file in the top-level Atomistica directory.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
# ======================================================================

"""
Test special cases where EAM potential may fail.
"""

from __future__ import print_function

import sys

import unittest

import numpy as np

import ase.io as io

from atomistica import TabulatedAlloyEAM

###

class TestEAMSpecialCases(unittest.TestCase):

    def test_crash1(self):
        a = io.read('eam_crash1.poscar')
        a.set_calculator(TabulatedAlloyEAM(fn='Cu_mishin1.eam.alloy'))
        a.get_potential_energy()

###

if __name__ == '__main__':
    unittest.main()