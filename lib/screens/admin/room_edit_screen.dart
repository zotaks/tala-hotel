import 'package:flutter/material.dart';

import '../../models.dart';
import '../../state/app_state.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/adaptive.dart';
import '../../widgets/motion.dart';
import '../../widgets/security_widgets.dart';
import 'manage_rooms_screen.dart';

/// Add or edit a room type (price, photos, inventory, visibility).
class RoomEditScreen extends StatefulWidget {
  const RoomEditScreen({super.key, this.room});
  final RoomType? room;
  @override
  State<RoomEditScreen> createState() => _RoomEditScreenState();
}

class _RoomEditScreenState extends State<RoomEditScreen> {
  static const categories = ['Standard', 'Deluxe', 'Suite'];
  late final RoomType? r = widget.room;
  late final name = TextEditingController(text: r?.name ?? '');
  late final price = TextEditingController(text: r == null ? '' : r!.price.round().toString());
  late final size = TextEditingController(text: '${r?.sizeSqm ?? 24}');
  late final beds = TextEditingController(text: r?.beds ?? '');
  late final desc = TextEditingController(text: r?.description ?? '');
  late final amenities = TextEditingController(text: (r?.amenities ?? const ['Free Wi-Fi', 'Air-conditioning']).join(', '));
  late String category = categories.contains(r?.category) ? r!.category : categories.first;
  late int capacity = r?.capacity ?? 2;
  late int units = r?.units ?? 1;
  late bool popular = r?.popular ?? false;
  late bool visible = r?.visible ?? true;
  late final List<String> photos = [...?r?.images];
  bool busy = false;

  @override
  void dispose() {
    for (final c in [name, price, size, beds, desc, amenities]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final p = double.tryParse(price.text.trim());
    if (name.text.trim().isEmpty || p == null || p <= 0) {
      toast(context, 'Enter a room name and a valid price', error: true);
      return;
    }
    setState(() => busy = true);
    final room = RoomType(
      id: r?.id ?? 0,
      name: name.text.trim(),
      category: category,
      description: desc.text.trim(),
      beds: beds.text.trim(),
      price: p,
      capacity: capacity,
      sizeSqm: int.tryParse(size.text.trim()) ?? 20,
      units: units,
      popular: popular,
      visible: visible,
      images: photos,
      amenities: amenities.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
    );
    final ok = await attempt(context, () => AppScope.read(context).saveRoom(room), success: r == null ? 'Room type added' : 'Changes saved');
    if (!mounted) return;
    setState(() => busy = false);
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: 'Delete ${r!.name}?', message: 'Only possible when it has no active bookings. Tip: hide it instead to keep its history.', confirm: 'Delete', danger: true);
    if (!ok || !mounted) return;
    // deleting is permanent → confirm it's really you
    final me = await askPassword(context, action: 'delete ${r!.name}');
    if (!me || !mounted) return;
    final done = await attempt(context, () => AppScope.read(context).deleteRoom(r!), success: 'Room type deleted');
    if (done && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[
      // ---------------------------------------- photos
      const SectionLabel('Photos', padding: EdgeInsets.fromLTRB(0, 4, 0, 10)),
      SizedBox(
        height: 96,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: photos.length + 1,
          itemBuilder: (_, i) {
            if (i == photos.length) {
              return Pressable(
                key: const ValueKey('add'),
                onTap: () async {
                  final url = await pickPhoto(context);
                  if (url != null) setState(() => photos.add(url));
                },
                child: Container(
                  width: 96,
                  decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(10)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.add_photo_alternate_outlined, color: C.muted),
                    SizedBox(height: 4),
                    Text('Add', style: T.small),
                  ]),
                ),
              );
            }
            return Padding(
              key: ValueKey('p$i${photos[i]}'),
              padding: const EdgeInsets.only(right: 8),
              child: Pressable(
                // tap a photo to make it the cover (first photo)
                onTap: i == 0 ? null : () => setState(() => photos.insert(0, photos.removeAt(i))),
                child: Stack(children: [
                  NetImage(photos[i], width: 96, height: 96, radius: 10),
                  if (i == 0)
                    Positioned(
                      left: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(4)),
                        child: const Text('COVER', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black)),
                      ),
                    ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Pressable(
                      onTap: () => setState(() => photos.removeAt(i)),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.close_rounded, size: 15, color: Colors.white),
                      ),
                    ),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
      Padding(padding: EdgeInsets.only(top: 6, bottom: 14), child: Text('Tap a photo to make it the cover. × removes it.', style: T.small)),

      // ---------------------------------------- basics
      Field(label: 'Room name', hint: 'e.g. Deluxe King', controller: name),
      const Text('Category', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Row(children: [
        for (var k = 0; k < categories.length; k++) ...[
          if (k > 0) const SizedBox(width: 8),
          Expanded(child: ChoiceTile(title: categories[k], selected: category == categories[k], height: 48, onTap: () => setState(() => category = categories[k]))),
        ],
      ]),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: Field(label: 'Price per night (₱)', hint: 'e.g. 3450', controller: price, keyboard: TextInputType.number)),
        const SizedBox(width: 10),
        Expanded(child: Field(label: 'Size (m²)', controller: size, keyboard: TextInputType.number)),
      ]),
      Field(label: 'Beds', hint: 'e.g. 1 King bed', controller: beds),
      AppCard(
        child: Column(children: [
          Row(children: [
            Expanded(child: Text('Max guests', style: T.title)),
            QtyStepper(value: capacity, min: 1, max: 10, onChanged: (v) => setState(() => capacity = v)),
          ]),
          Divider(height: 24, color: C.line),
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Rooms of this type', style: T.title),
                Text('How many can be booked per night', style: T.small),
              ]),
            ),
            QtyStepper(value: units, min: 0, max: 99, onChanged: (v) => setState(() => units = v)),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      Field(label: 'Description', hint: 'What makes this room special?', controller: desc, maxLines: 4),
      Field(label: 'Amenities (comma separated)', hint: 'Free Wi-Fi, Smart TV, Bathtub', controller: amenities, maxLines: 2),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: visible,
            onChanged: (v) => setState(() => visible = v),
            title: Text('Show to guests', style: T.title),
            subtitle: Text('Hidden rooms can\'t be booked', style: T.small),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: popular,
            onChanged: (v) => setState(() => popular = v),
            title: Text('Mark as popular', style: T.title),
            subtitle: Text('Shows an orange POPULAR badge', style: T.small),
          ),
        ]),
      ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          BackHeader(
            title: r == null ? 'New room type' : 'Edit ${r!.name}',
            trailing: r == null ? null : IconButton(onPressed: _delete, icon: Icon(Icons.delete_outline_rounded, color: C.danger)),
          ),
          Expanded(
            child: SplitList(left: parts.sublist(0, 10), right: parts.sublist(10)),
          ),
        ]),
      ),
      bottomNavigationBar: BottomBar(
        child: Row(children: [
          Expanded(child: Btn('Cancel', style: BtnStyle.secondary, onTap: () => Navigator.of(context).pop())),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: Btn('Save', loading: busy, onTap: _save)),
        ]),
      ),
    );
  }
}
