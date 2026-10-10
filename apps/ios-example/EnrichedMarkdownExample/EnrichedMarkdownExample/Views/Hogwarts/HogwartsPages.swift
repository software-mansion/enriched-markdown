/// One page of the spellbook per spell, all built from the same template
/// so the parchment keeps the same height: a heading, an italic intro with
/// the incantation as inline code and a ==marked== phrase, three spoiler
/// lines, a quote with a hidden answer, an ornamental rule, and a sign-off.
/// Every line is short enough to stay on one line at the
/// page's type size, and a couple of labels cross out an alias.
enum HogwartsPages {
    private struct Page {
        let title: String
        let incantation: String
        let intro: String
        let lines: [(label: String, secret: String)]
        let quote: (lead: String, secret: String)
        let closer: String

        var markdown: String {
            let body = lines.map { "**\($0.label)** ||\($0.secret)||" }.joined(separator: "\n\n")
            return """
            ## \(title)

            *`\(incantation)` · \(intro)*

            \(body)

            > \(quote.lead) ||\(quote.secret)||

            ---

            \(closer)
            """
        }
    }

    static func markdown(for spell: SpoilerShowcaseOverlay) -> String {
        (pages[spell] ?? pages[.revelio] ?? prophet).markdown
    }

    private static let prophet = Page(
        title: "The Daily Prophet 🦉",
        incantation: "Revelio",
        intro: "Spoilers ahead, ==tap to reveal==.",
        lines: [
            ("The Half-Blood Prince is", "Severus Snape."),
            ("Scabbers the rat is", "Peter Pettigrew."),
            ("The final Horcrux is", "Harry himself.")
        ],
        quote: ("\"After all this time?\"", "\"Always.\""),
        closer: "Mischief managed 🪄"
    )

    private static let pages: [SpoilerShowcaseOverlay: Page] = [
        .revelio: prophet,
        .map: Page(
            title: "The Marauder's Map 🗺️",
            incantation: "Aparecium",
            intro: "By ==the Marauders==.",
            lines: [
                ("Moony is", "Remus Lupin."),
                ("Wormtail is", "Peter Pettigrew."),
                ("~~Snuffles~~ Padfoot is", "Sirius Black.")
            ],
            quote: ("It opens with", "\"I solemnly swear.\""),
            closer: "Mischief managed 🪄"
        ),
        .snitch: Page(
            title: "Quidditch Times 🏆",
            incantation: "Accio",
            intro: "Reports ==from the pitch==.",
            lines: [
                ("Youngest Seeker:", "Harry Potter."),
                ("Harry's first catch:", "he swallowed it."),
                ("In the Snitch:", "the Resurrection Stone.")
            ],
            quote: ("\"I open", "at the close.\""),
            closer: "Gryffindor wins 🦁"
        ),
        .lumos: Page(
            title: "Nocturnal Notes 🕯️",
            incantation: "Lumos",
            intro: "Things seen ==by wandlight==.",
            lines: [
                ("Room of Requirement:", "the seventh floor."),
                ("Sirius's gift:", "a two-way mirror."),
                ("Ron's inheritance:", "the Deluminator.")
            ],
            quote: ("\"Nox,\" he said,", "and it went dark."),
            closer: "Turn on the light ✨"
        ),
        .patronus: Page(
            title: "Patronus Registry 🦌",
            incantation: "Expecto Patronum",
            intro: "Charms ==on record==.",
            lines: [
                ("Harry's Patronus:", "a stag."),
                ("Snape's Patronus:", "a doe."),
                ("Hermione's Patronus:", "an otter.")
            ],
            quote: ("Luna's Patronus is", "a hare."),
            closer: "Think of something happy 💫"
        ),
        .floo: Page(
            title: "Floo Network 🔥",
            incantation: "Diagon Alley",
            intro: "==Mind the grate==.",
            lines: [
                ("Harry's first trip:", "Knockturn Alley."),
                ("Diagon Alley grate:", "the Leaky Cauldron."),
                ("The Weasleys' fireplace:", "the Burrow.")
            ],
            quote: ("\"Diagonally,\"", "and he vanished."),
            closer: "Mind the soot 🧹"
        ),
        .apparition: Page(
            title: "Apparition Licence 💨",
            incantation: "Apparate",
            intro: "==Destination, Determination==.",
            lines: [
                ("Legal age to Apparate:", "seventeen."),
                ("Splinched in the woods:", "Ron."),
                ("Inside Hogwarts, only", "house-elves can.")
            ],
            quote: ("\"Squeezed", "through a tube.\""),
            closer: "Crack 💥"
        ),
        .howler: Page(
            title: "Owl Post 📮",
            incantation: "Sonorus",
            intro: "Post, ==some of it shouting==.",
            lines: [
                ("Ron's Howler was about", "the flying car."),
                ("It was ~~posted~~ sent by", "Molly Weasley."),
                ("Neville's Howler was about", "the passwords.")
            ],
            quote: ("\"STEALING THE CAR!\"", "she roared."),
            closer: "Open it, it's worse otherwise 📣"
        ),
        .timeTurner: Page(
            title: "Ministry Records ⏳",
            incantation: "Tempus",
            intro: "==Registered use==, 1993 to 1994.",
            lines: [
                ("Lent to", "Hermione Granger."),
                ("Approved by", "Professor McGonagall."),
                ("Used to save", "Buckbeak and Sirius.")
            ],
            quote: ("\"Three turns,\"", "said Dumbledore."),
            closer: "You must not be seen 🕰️"
        ),
        .sortingHat: Page(
            title: "The Sorting 🎩",
            incantation: "Sorting",
            intro: "==First of September==.",
            lines: [
                ("Harry nearly went to", "Slytherin."),
                ("Hermione's other option:", "Ravenclaw."),
                ("The Hat was made by", "Godric Gryffindor.")
            ],
            quote: ("\"Better be…", "GRYFFINDOR!\""),
            closer: "Not Slytherin, not Slytherin 🦁"
        ),
        .fiendfyre: Page(
            title: "Room of Requirement 🔥",
            incantation: "Fiendfyre",
            intro: "Found ==among the ashes==.",
            lines: [
                ("The fire was cast by", "Vincent Crabbe."),
                ("It destroyed", "the diadem Horcrux."),
                ("Rescued by broom:", "Draco and Goyle.")
            ],
            quote: ("\"It hunts you,\"", "Hermione said."),
            closer: "Cursed fire never sleeps 🐉"
        ),
        .portkey: Page(
            title: "Portkey Office 🥾",
            incantation: "Portus",
            intro: "Touch ==at your peril==.",
            lines: [
                ("The World Cup Portkey:", "an old boot."),
                ("The Triwizard Cup led to", "the graveyard."),
                ("It was enchanted by", "Barty Crouch Jr.")
            ],
            quote: ("\"Three, two,", "one.\""),
            closer: "Hold on tight 🌀"
        ),
        .feathers: Page(
            title: "Owlery Notices 🦉",
            incantation: "Levioso",
            intro: "Deliveries ==by wing==.",
            lines: [
                ("Harry's owl:", "Hedwig."),
                ("Ron's tiny owl:", "Pigwidgeon."),
                ("Errol belongs to", "the Weasleys.")
            ],
            quote: ("Hedwig fell in", "the Seven Potters."),
            closer: "Owl treats in the tin 🪶"
        ),
        .riddikulus: Page(
            title: "Defence Homework 😄",
            incantation: "Riddikulus",
            intro: "==How to beat== a boggart.",
            lines: [
                ("Ron's ~~fear~~ boggart:", "a spider."),
                ("Lupin's boggart:", "the full moon."),
                ("Harry's boggart:", "a Dementor.")
            ],
            quote: ("Snape ended up in", "Gran's clothes."),
            closer: "Laughter finishes it 🎭"
        ),
        .expelliarmus: Page(
            title: "Duelling Club ⚡",
            incantation: "Expelliarmus",
            intro: "Harry's ==signature spell==.",
            lines: [
                ("First seen cast by", "Professor Snape."),
                ("Harry disarmed Snape", "in the Shack."),
                ("It beat Voldemort in", "the Great Hall.")
            ],
            quote: ("\"Expelliarmus!\"", "The wand flew."),
            closer: "Priori Incantatem ✨"
        )
    ]
}
