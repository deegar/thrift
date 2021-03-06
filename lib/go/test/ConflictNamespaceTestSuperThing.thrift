#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements. See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership. The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.
#
namespace go conflict.super

include "ConflictNamespaceTestA.thrift"
include "ConflictNamespaceTestB.thrift"
include "ConflictNamespaceTestC.thrift"
include "ConflictNamespaceTestD.thrift"
include "ConflictNamespaceTestE.thrift"
include "ConflictNamespaceTestF.thrift"

struct SuperThing {
  1: ConflictNamespaceTestA.ThingA thing_a
  2: ConflictNamespaceTestB.ThingB thing_b
  3: ConflictNamespaceTestC.ThingC thing_c
  4: ConflictNamespaceTestD.ThingD thing_d
  5: ConflictNamespaceTestE.ThingE thing_e
  6: ConflictNamespaceTestF.ThingF thing_f
}

// Define an enum to force the import of database/sql/driver
enum Enum {
  One = 1
  Two = 2
}
