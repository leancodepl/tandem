import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:greenhouse_app/look_cubit.dart';
import 'package:kit_ds/kit_ds.dart';
import 'package:tandem/tandem.dart';
import 'package:tandem/testing.dart';

void main() {
  test("Tandem's color keeps the alpha, the insets their direction", () async {
    final cubit = LookCubit();
    final listing = AgentListing.of(cubit);

    await listing.call('set_padding', {'padding': '8 16'});
    final symmetric = cubit.padding;
    await listing.call('set_padding', {'padding': 'top 8 start 16'});

    expect(listing.seen['accent'], '#2e7d3280');
    expect(
      symmetric,
      const EdgeInsetsDirectional.symmetric(vertical: 8, horizontal: 16),
    );
    expect(
      cubit.padding.resolve(.rtl),
      const EdgeInsets.only(top: 8, right: 16),
    );
    await expectLater(
      listing.call('set_padding', {'padding': 'left 4'}),
      throwsA(
        isA<ToolCallRefused>().having(
          (error) => error.message,
          'message',
          'padding: Name start and end, not left or right.',
        ),
      ),
    );
    await expectLater(
      listing.call('set_padding', {'padding': 'Infinity'}),
      throwsA(isA<ToolCallRefused>()),
    );
  });

  test(
    "the app's and the design system's converters read their forms",
    () async {
      final cubit = LookCubit();
      final listing = AgentListing.of(cubit);

      await listing.call('set_icon', {'icon': 'sun'});
      await listing.call('set_ink', {'ink': 'ember'});

      expect(cubit.icon, const IconData(0xe430));
      expect(
        const InkConverter().toJson(cubit.ink ?? (throw StateError('none'))),
        InkName.ember,
      );
      await expectLater(
        listing.call('set_icon', {'icon': 'rose'}),
        throwsA(
          isA<ToolCallRefused>().having(
            (error) => error.message,
            'message',
            'icon: Write one of leaf, drop, sun.',
          ),
        ),
      );
    },
  );
}
