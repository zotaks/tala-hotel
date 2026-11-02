import 'package:flutter/material.dart';

import '../../data/seed_data.dart';
import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../utils/format.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/cards.dart';
import '../../widgets/common.dart';
import '../../widgets/motion.dart';
import 'room_edit_screen.dart';

class ManageRoomsScreen extends StatefulWidget {
  const ManageRoomsScreen({super.key});
  @override
  State<ManageRoomsScreen> createState() => _ManageRoomsScreenState();
}

class _ManageRoomsScreenState extends State<ManageRoomsScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return ListView(padding: const EdgeInsets.only(bottom: 28), children: [
      PageHeader(
        title: tab == 0 ? 'Rooms' : 'Extras',
        subtitle: tab == 0 ? 'Price, photos and inventory per room type' : 'Add-ons guests can pick when booking',
        actions: [
          SquareIconButton(
            icon: Icons.add_rounded,
            onTap: () => tab == 0 ? go(context, const RoomEditScreen()) : sheet(context, const AddonEditSheet()),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SegmentToggle(options: const ['Room types', 'Extras'], index: tab, onChanged: (i) => setState(() => tab = i)),
      ),
      const SizedBox(height: 14),
      KeyedSubtree(
        key: ValueKey('tab$tab'),
        child: tab == 0 ? _roomsList(context, s) : _addonsList(context, s),
      ),
    ]);
  }

  Widget _roomsList(BuildContext context, AppState s) => Column(children: [
        AdaptiveGrid(children: [
        for (var i = 0; i < s.rooms.length; i++)
          FadeSlideIn(
            index: i,
            child: Stack(children: [
                AppCard(
                  dim: !s.rooms[i].visible,
                  onTap: () => go(context, RoomEditScreen(room: s.rooms[i])),
                  padding: EdgeInsets.zero,
                  color: Colors.transparent,
                  child: RoomListCard(room: s.rooms[i], heroPrefix: 'admin', freeTonight: s.freeOn(s.rooms[i], today())),
                ),
                if (!s.rooms[i].visible)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(5)),
                      child: const Text('HIDDEN', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
                    ),
                  ),
              ]),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Text('${s.totalUnits} rooms in total across ${plural(s.visibleRooms.length, 'visible type')}.', style: T.small, textAlign: TextAlign.center),
        ),
      ]);

  Widget _addonsList(BuildContext context, AppState s) => Column(children: [
        if (s.addons.isEmpty) const EmptyState(icon: Icons.room_service_outlined, title: 'No extras yet', text: 'Tap + to add breakfast, spa, pickup…'),
        AdaptiveGrid(children: [
        for (var i = 0; i < s.addons.length; i++)
          FadeSlideIn(
            index: i,
            child: AppCard(
                dim: !s.addons[i].active,
                padding: const EdgeInsets.all(12),
                onTap: () => sheet(context, AddonEditSheet(addon: s.addons[i])),
                child: Row(children: [
                  NetImage(s.addons[i].image, width: 60, height: 60, radius: 10, icon: Icons.room_service_rounded),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.addons[i].name, style: T.title),
                      Text(s.addons[i].description, style: T.small, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  Text(peso(s.addons[i].price), style: T.price),
                  Icon(Icons.chevron_right_rounded, color: C.muted),
                ]),
              ),
          ),
        ]),
      ]);
}

/// Add / edit an extra (bottom sheet).
class AddonEditSheet extends StatefulWidget {
  const AddonEditSheet({super.key, this.addon});
  final Addon? addon;
  @override
  State<AddonEditSheet> createState() => _AddonEditSheetState();
}

class _AddonEditSheetState extends State<AddonEditSheet> {
  late final name = TextEditingController(text: widget.addon?.name ?? '');
  late final desc = TextEditingController(text: widget.addon?.description ?? '');
  late final price = TextEditingController(text: widget.addon == null ? '' : widget.addon!.price.round().toString());
  late final image = TextEditingController(text: widget.addon?.image ?? '');
  late bool active = widget.addon?.active ?? true;
  bool busy = false;

  @override
  void dispose() {
    for (final c in [name, desc, price, image]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final p = double.tryParse(price.text.trim());
    if (name.text.trim().isEmpty || p == null) {
      toast(context, 'Enter a name and a price', error: true);
      return;
    }
    setState(() => busy = true);
    final ok = await attempt(
      context,
      () => AppScope.read(context).saveAddon(Addon(id: widget.addon?.id ?? 0, name: name.text.trim(), description: desc.text.trim(), price: p, image: image.text.trim(), active: active)),
      success: 'Extra saved',
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(widget.addon == null ? 'New extra' : 'Edit extra', style: T.h2)),
            if (widget.addon != null)
              TextButton(
                onPressed: () async {
                  final ok = await confirmDialog(context, title: 'Delete ${widget.addon!.name}?', message: 'Past bookings keep their price.', confirm: 'Delete', danger: true);
                  if (!ok || !context.mounted) return;
                  final done = await attempt(context, () => AppScope.read(context).deleteAddon(widget.addon!), success: 'Extra deleted');
                  if (done && context.mounted) Navigator.of(context).pop();
                },
                child: Text('Delete', style: TextStyle(color: C.danger, fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            NetImage(image.text, width: 72, height: 72, radius: 10, icon: Icons.room_service_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Btn('Pick a photo', style: BtnStyle.secondary, height: 44, icon: Icons.photo_library_outlined, onTap: () async {
                final url = await pickPhoto(context);
                if (url != null) setState(() => image.text = url);
              }),
            ),
          ]),
          const SizedBox(height: 14),
          Field(label: 'Name', hint: 'e.g. Breakfast for two', controller: name),
          Field(label: 'Short description', hint: 'e.g. Daily buffet, 6–10 AM', controller: desc),
          Field(label: 'Price per stay (₱)', hint: 'e.g. 650', controller: price, keyboard: TextInputType.number),
          Field(label: 'Photo URL', hint: 'https://…', controller: image, onChanged: (_) => setState(() {})),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: active,
            onChanged: (v) => setState(() => active = v),
            title: Text('Show to guests', style: T.title),
          ),
          const SizedBox(height: 8),
          Btn('Save', loading: busy, onTap: _save),
        ]),
      );
}

/// Grid of ready-made hotel photos (or paste your own URL).
Future<String?> pickPhoto(BuildContext context) => sheet<String>(
      context,
      SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text('Choose a photo', style: T.h2),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text('Free photos from Unsplash. You can also paste any image URL.', style: T.small),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
              itemCount: photoGallery.length,
              itemBuilder: (ctx, i) => FadeSlideIn(
                index: i,
                child: Pressable(onTap: () => Navigator.of(ctx).pop(photoGallery[i]), child: NetImage(photoGallery[i], radius: 10)),
              ),
            ),
          ),
        ]),
      ),
    );
