import 'package:example/invoices/invoice_app.dart';
import 'package:flutter/material.dart';
import 'package:tandem/tandem.dart';

void main() => runApp(InvoiceApp(connection: OnDeviceAgent.apple()));
