extends RefCounted
const GROUPS=["Samurai","Shinobi","Tiny Heroes","Satyrs","Academy","Street Artists"]
const COLORS=["efac70","b0aaf1","ef96be","8ed1a8","f3c978","75d8bc"]
const HEROES=[
["Gateblade","Counterguard","Every third cut softens the next melee hit.","Stillwater Counter","Guard the next blow and strike back.","Twin Guard","Counter on both stairs.","Life Guard","Gain 16 HP on a clean block."],
["Farstring","Sharpshooter","Arrows hit harder from a distance.","Thread the Gate","Pierce every enemy on one stair.","Arrow Flurry","Fire three piercing shots.","Last Pin","Pin and interrupt the last foe."],
["Red Banner","Commander","Every fourth cut orders an extra party attack.","Raise the Standard","Raise attack speed for the whole squad.","Iron Standard","Gain a barrier on cast.","Breach Volley","The opening volley strips armor."],
["Smoke","Assassin","Knives deal bonus damage during enemy windups.","Backline Shadow","Send a double to interrupt the back rank.","Second Shadow","Leap again on a knockout.","Paper Decoy","Catch the next enemy shot."],
["Copper Heel","Brawler","Every third strike staggers its target.","Rising Heel","Launch a foe and interrupt its attack.","Aftershock","Landing damages nearby foes.","Iron Heel","Break armor on contact."],
["Moon Ronin","Duelist","Changing flanks adds a follow-up cut.","Twin Crescent","Send a blade wave down each stair.","Moon Return","Both waves strike on return.","Double Draw","Send both cuts to the focus side."],
["Pip","Demolitions","Freshly pushed foes take a double punch.","Pop Rock","Stick a pebble to a foe. The next hit detonates it.","Rock Cluster","Seed neighbors with pebbles.","Hard Candy","The blast strips armor."],
["Owlet","Spotter","First stones mark foes. The next party hit deals bonus damage.","Bank Shot","Bounce a stone through three targets.","Cross Bank","Bounce between both stairs.","Lone Star","Bounce repeatedly on a lone foe."],
["Rook","Bulwark","Heavy jabs push back close enemies.","Boulder Roll","Roll a rock down a stairway.","Roadblock","Leave a temporary barricade.","Stone Rain","Shards strike the rear rank."],
["Briar","Grove Healer","Every third bolt heals the party.","Bramble Knot","Root a group of foes in place.","Lifebloom","Heal while the roots hold.","Thorn Relay","Roots spread to the other stair."],
["Vesper","Stormcaller","Three hits on one foe discharge a spark.","Forked Storm","Chain lightning through several enemies.","Hush Bolt","Silence the final enemy.","Arc Return","Send a final bolt to the first."],
["Reed","Windcaller","Blades clip foes behind a wounded target.","Crosswind","Drive a group back with a gust.","Eye of Wind","Pull the group together.","Turnabout","Reflect incoming enemy shots."],
["Mina","Bookbinder","Two hits bookmark a foe for extra return damage.","Overdue","Throw your textbook through a line and back.","Quiet Please","The returning book silences casters.","Footnote","Jump to another bookmarked foe."],
["Relay Captain","Striker","Collisions briefly increase attack speed.","Relay Kick","Kick the lead enemy into the one behind it.","Relay Chain","Chain up to three collisions.","First Break","Break armor on first impact."],
["Hall Monitor","Warden","First contact with a new enemy slows it.","Quiet Zone","Draw a chalk ward that catches shots.","Return Slip","Reflect the last caught shot.","First Aid","Absorbed shots heal the party."],
["Matchstick","Firestarter","Three paint hits on the same target ignite it.","Hot Stencil","Leave burning paint across the stair.","Wildfire","Burning foes spread fire on defeat.","Flash Point","Ring the bell to detonate paint."],
["Gilt","Illusionist","Outlines empower the next basic hit from any ally.","Carbon Copy","Paint a double that copies the leader's basic.","Diptych","Put a double on each flank.","True Copy","Copies inherit on-hit passives."],
["Verdigris","Armorbreaker","Green spray corrodes armor on every hit.","Peel Coat","Dissolve a shield and splash the rear rank.","Glass Rain","Fragments damage the rear rank.","Patina","Fragments form a party barrier."]]
const RANGED=[1,7,9,10,11,12,15,16,17]
const SPEEDS=[0.93,1.0,1.03,0.73,0.79,0.91,0.73,0.94,1.03,0.94,0.95,0.88,0.99,0.78,0.83,0.85,0.88,0.9]
const DAMAGE=[13.0,11.0,13.0,10.5,11.0,12.5,10.4,11.0,14.0,10.8,11.5,11.6,12.0,11.0,11.4,11.0,11.2,10.8]
const REGION=["Copper Crossing","Lantern Quarter","Rainwood Gate","Violet Junction"]
const CHARMS=["None","Chipped Clapper","Silk Knot","Jade Coin"]
const CHARM_DESC=["No starting charm.","Perfect rings recover 2s.","Clear a wave to heal 9 extra HP.","Earn 30% more gold on victory."]
const WEAPONS=["Standard issue","Copper Edge","Glass Fang","Starforged Edge"]
const WEAPON_DESC=["Base damage.","+12% attack damage.","+22% attack damage.","+35% attack damage."]
const TYPES=["Cinder","Runner","Shield Porter","Lantern Sniper","War Drummer","Tollkeeper","Mirror Guard"]
const FORM=["Lantern patrol","Split rush","Shield convoy","Decoy escort","Crossfire"]
