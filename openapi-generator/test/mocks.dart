import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:mockito/annotations.dart';
import 'package:openapi_generator/src/openapi_generator_runner.dart';
import 'package:source_gen/source_gen.dart';

@GenerateNiceMocks([
  MockSpec<OpenapiGenerator>(),
  MockSpec<ConstantReader>(),
  MockSpec<BuildStep>(),
  MockSpec<MethodElement>(),
  MockSpec<ClassElement>(),
  MockSpec<Process>(),
])
void main() {}
