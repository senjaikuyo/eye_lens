import 'package:flutter/material.dart';

/// Global RouteObserver to detect screen visibility (e.g. pausing camera on route change).
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();
