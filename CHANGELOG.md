# Changes

## 1.5.1

- **No new addon needed.** Luredon works on its own as before.
- **Lighter:** chat lines and the reasons to bring the interface back are only watched while Luredon hides the interface; the shared fishing totals are kept smaller (2000 entries, 10 players each), and older saved data is thinned once.
- **Shared base:** options and window style come from DonCore, the common base of the Don addons. Nothing changes for you.

## 1.5.0

- **The family look:** the fishing book and the Luredon windows now wear the darker colours of Guildon, with gold lines on dark blue.
- **Buttons you can see:** every filter button has a frame, turns gold under the mouse and blue when chosen. The fish kind and the zone you picked are blue with a bar on the left.
- **Tabs:** the open tab of the fishing book is gold, the others are grey and light up under the mouse.
- **Search field:** a clear frame, blue while you type, and a cross to empty it.
- **Export window and the question about hiding the interface** have the same look; "Yes" and "No" are real buttons now.
- **Options from the book:** a gear button next to the close button opens the Luredon options.
- **The book remembers its tab,** also after a /reload.

## 1.4.2

- **Open data only:** the fish of each zone and the skill a zone needs now come from the open Classic database CMaNGOS (its fishing loot); Zephras Isle keeps Luredon's own catches. Shares can differ a little from before, fish from pools are not in the lists.

## 1.4.1

- **Update note:** new files, so restart the game after updating (a /reload is not enough).
- **Chat while the interface is hidden:** new whispers, guild, group and raid messages now show at the bottom left while Luredon hides the interface, and fade out after 20 seconds. A whisper no longer brings the interface back. Choose "All chat" to see say, yell and channels too, or switch it off, under Options > Casting and lures.
- **Bobber at the mouse pointer:** while the mouse is on your bobber, a small red and white bobber with a golden rim sits at the pointer. In the last seconds before the line comes in by itself it turns amber, green when you caught something and red when the fish got away. Switch it off under Options > Sound and hooking.
- **Fishing book in a new look:** the book now matches Questdon's quest book: a gold frame on dark blue, framed tabs, every session, fish and zone as a card, today's numbers as cards and the zone you fish in as a round map in a gold ring. Click the map to open that zone under Waters. The Luredon window wears the same look now: a gold frame with ornaments on dark blue and gold bars.
- **Cast bar without the interface:** while Luredon hides the interface, your own fishing cast bar stays visible at the bottom centre, with the time left (6.6s, with the decimal comma of your language).
- **Invitations reach you while the interface is hidden:** a party or guild invitation, a duel, trade or summon request, a resurrection, a ready check, a loot roll or a quest someone shares now brings the interface back, so nothing times out unseen. It also comes back as soon as you start typing.
- **Alt+Z stays yours:** if you bring the interface back with Alt+Z while Luredon hides it, Luredon lets go and its own lines disappear; the next cast hides it again. If you hid the interface yourself, Luredon leaves it hidden when you move.
- **Auto Loot tip:** with hiding on and Auto Loot off, Luredon says once that each loot window brings the interface back, and how to avoid it (Auto Loot or Shift-click). Luredon never loots for you.
- **Summary per fishing stretch:** the chat summary when you take off your pole now covers only that stretch of fishing: casts, fish, getaways, missed bites, skill before and after, new kinds, value and fish per hour.
- **Missed bites:** a line that comes in by itself without a catch now counts as a missed bite, in the session tooltip, the fishing book and the summary. Moving or a fight never counts.
- **Zephras Isle has its fish:** the zone tooltip and the fishing book now list the fish of Zephras Isle (from Luredon's own catches, and they say so).

## 1.4.0

- **Fish without the interface:** if you like, Luredon hides the whole game interface while your line is out, like Alt+Z, and brings it back when you move, a fight starts, you change the target or get a whisper. Your catches show as a ticker at the top of the screen. Luredon asks once; change it any time under Options > Casting and lures. A skill point shows under your catches, and warnings such as full bags or a missing lure appear there in red, since the game's own error line is hidden too.
- **Lure warning:** "Your fishing pole has no lure" now only comes on the first two casts without one in a row. Fishing without a lure on purpose stays quiet; with a lure on the pole the count starts again.
- **Start zones:** below skill 25 the window no longer shows the zone's skill in red as if something were wrong. It says calmly from which skill no fish gets away (Zephras Isle, where the Skyborne start, and the other start zones).
- **Window buttons:** the buttons in the Luredon windows can be clicked again when an action bar addon such as Bartender4 sits underneath.

## 1.3.0

- **Fishing book:** a new large window with three tabs. Open it with /ld book or the "Fishing book" line in the Luredon window.
  - **Logbook:** every fishing session with zone, time, fish, getaways, fish per hour and value; rare catches, skill milestones and new records in between, today's numbers on top.
  - **Fish atlas:** every fish and container as a card: caught ones with count and first catch, missing ones with where they bite and the skill they need.
  - **Waters:** every zone with the skill it needs, its map, your numbers there and its fish, with the data's share next to yours.
- **Translations:** French, Spanish (Spain and Latin America), Brazilian Portuguese, Russian, Korean and Traditional Chinese.

## 1.2.0

- **Fish of the zone:** the zone tooltip and the catch log show which fish can be caught where you are, which ones you already caught there and which are still new to you.

## 1.1.0

- **Fish together:** Luredon now shares your fishing totals with Luredon players in your guild and group (only numbers, no names). Option "Share fishing data with guild and group", on by default.
- **Zones you have not fished yet:** the zone tooltip shows what others caught there.
- **Skill for new zones:** where no value is published yet, Luredon shows the skill other players needed so that nothing gets away.
- **Skill-up estimates** start right away, based on other players' casts per point until you have your own.

## 1.0.0

First release on CurseForge.
