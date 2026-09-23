import { Link } from "react-router-dom";

import LegalPage, { LegalList, Strong, type LegalSection } from "@/components/site/LegalPage";
import { usePageTitle } from "@/hooks/use-page-title";
import { SITE } from "@/lib/site";

const email = (
  <a href={`mailto:${SITE.supportEmail}`} className="text-link break-all">
    {SITE.supportEmail}
  </a>
);

const SECTIONS: ReadonlyArray<LegalSection> = [
  {
    id: "summary",
    title: "The short version",
    body: (
      <LegalList
        items={[
          <>
            <Strong>Your practice video stays on your iPhone.</Strong> Pose estimation, rep detection and scoring run
            on-device. Raw video is never uploaded to any server.
          </>,
          <>
            <Strong>Cloud sync is optional.</Strong> If you sign in, your account data (profile, sessions, rep scores,
            mechanic history, practice plans and settings) is backed up to our cloud so it survives a new phone.
          </>,
          <>
            <Strong>Research sharing is off by default.</Strong> You choose whether anonymized practice data may be
            used to improve scoring.
          </>,
          <>
            <Strong>You can delete your data at any time</Strong>, in the app or by emailing us.
          </>,
          <>
            <Strong>We don't sell your data</Strong>, show ads, or track you across other apps and websites.
          </>,
        ]}
      />
    ),
  },
  {
    id: "camera",
    title: "Camera and practice video",
    body: (
      <>
        <p>
          {SITE.product} uses your iPhone camera during a practice session to find your body position (pose
          estimation), detect each swing and score your mechanics. All of this runs on your device.{" "}
          <Strong>Raw video is not uploaded to any server</Strong>, and we never see it.
        </p>
        <LegalList
          items={[
            <>
              The camera feed is held briefly in memory while you practice. By default the app saves a short clip (about
              three seconds) around each detected rep so you can review it. The rest is discarded.
            </>,
            <>
              Saved clips live only in the app's storage on your iPhone. They are never synced to the cloud. You can
              turn clip saving off, choose how long clips are kept (3–30 days), or delete them all in Settings → Privacy
              &amp; data.
            </>,
            <>
              {SITE.product} does not use the microphone. Spoken coaching cues are generated on-device by iOS.
            </>,
          ]}
        />
      </>
    ),
  },
  {
    id: "on-device",
    title: "Data stored on your device",
    body: (
      <p>
        Whether or not you sign in, the app stores your practice data locally on your iPhone: your profile and
        onboarding answers, sessions, rep scores and measurements, mechanic history, achievements, practice plans and
        settings. It stays on your device unless you sign in to cloud sync, as described below. Deleting the app removes
        this local data.
      </p>
    ),
  },
  {
    id: "cloud",
    title: "Account data and cloud sync",
    body: (
      <>
        <p>
          Signing in with Apple or Google is optional. Once you sign in, {SITE.product} syncs a copy of your account
          data to our cloud backend so it can be restored on another device. What syncs:
        </p>
        <LegalList
          items={[
            <>
              <Strong>Profile:</Strong> display name, the email address from your sign-in provider, your DUPR rating
              range, handedness, height, playing style, goals, and training preferences you choose in onboarding.
            </>,
            <>
              <Strong>Practice history:</Strong> sessions, rep scores, shot types, per-mechanic measurements and the
              body-position keypoints (numeric joint coordinates) the app derives from each rep. These are numbers, not
              images or video.
            </>,
            <>
              <Strong>Progress and plans:</Strong> mechanic history, achievements, practice plans and any feedback you
              record in the app.
            </>,
            <>
              <Strong>Settings:</Strong> your in-app preferences, including your research-sharing choice.
            </>,
          ]}
        />
        <p>
          When you sign in, your sign-in provider tells us an account identifier, your email address and, if you allow
          it, your name. We use your account only to store and restore your data, provide subscription and code
          benefits, and answer support requests.
        </p>
      </>
    ),
  },
  {
    id: "research",
    title: "Optional research sharing",
    body: (
      <>
        <p>
          In Settings → Privacy &amp; data there's a <Strong>"Help improve scoring"</Strong> setting.{" "}
          <Strong>It is off by default.</Strong>
        </p>
        <LegalList
          items={[
            <>
              While it's on, new sessions and reps are marked as OK to use in work that improves {SITE.product}'s rep
              detection and scoring. Records saved while it was off are never marked.
            </>,
            <>
              Before we use marked data, we anonymize it by removing your name, email address and account identifiers.
              Video is never included, because video never leaves your device.
            </>,
            <>
              You can turn the setting off at any time. New records stop being marked right away, and deleting your data
              also removes anything you previously marked.
            </>,
          ]}
        />
      </>
    ),
  },
  {
    id: "subscriptions",
    title: "Subscriptions, offer codes and friend codes",
    body: (
      <>
        <p>
          {SITE.product} Pro subscriptions are sold and billed by Apple through the App Store. Apple handles your payment
          details. We never receive your card number or billing address. The app gets confirmation from Apple of whether
          your subscription is active so it can unlock Pro.
        </p>
        <p>
          App Store offer codes are redeemed in Apple's own redemption screen and handled by Apple. Friend codes are
          redeemed with our backend. For these we record the code, your account identifier, your email and the time of
          redemption, so each code's limits can be enforced and your free access applied.
        </p>
      </>
    ),
  },
  {
    id: "analytics",
    title: "Usage analytics",
    body: (
      <p>
        The app counts basic usage events on your device (for example, how many reps were detected or rejected) to help
        measure detection accuracy. These counts currently stay on your iPhone and are not sent to us. You can turn them
        off in Settings → Privacy &amp; data. If we ever start collecting usage analytics, we'll update this policy
        first. It will never include video or be used for advertising.
      </p>
    ),
  },
  {
    id: "sharing",
    title: "How we share data",
    body: (
      <>
        <p>
          <Strong>We do not sell your personal data</Strong>, and we don't share it with advertisers or data brokers. We
          share data only:
        </p>
        <LegalList
          items={[
            <>
              With service providers who run our infrastructure on our behalf, under contract and only as needed to
              provide the service: our cloud hosting provider (Cloudflare), our sign-in and authentication providers,
              and Apple for App Store purchases.
            </>,
            <>When required by law, or to protect the rights, safety and security of our users or the public.</>,
            <>
              As part of a merger, acquisition or sale of assets, in which case this policy will continue to apply to
              your data.
            </>,
          ]}
        />
      </>
    ),
  },
  {
    id: "deletion",
    title: "Deleting your data",
    body: (
      <>
        <p>You can delete your data at any time:</p>
        <LegalList
          items={[
            <>
              <Strong>In the app:</Strong> Settings → Account → Delete all data. If you're signed in, this deletes your
              cloud account data first and then everything on your device.
            </>,
            <>
              <Strong>By email:</Strong> write to {email} from the email address on your account with the subject
              "Privacy request". We'll confirm and complete the deletion within 30 days.
            </>,
          ]}
        />
        <p>
          After deletion we keep only an anonymous record that an account identifier redeemed a given friend code, with
          your email removed, so that code's redemption limits stay accurate. We may also keep data where the law
          requires it. Canceling a subscription is separate: manage it in your Apple Account settings.
        </p>
      </>
    ),
  },
  {
    id: "retention-security",
    title: "Retention and security",
    body: (
      <>
        <p>
          We keep cloud account data until you delete it or ask us to. Clips on your device are removed automatically
          after the retention period you choose.
        </p>
        <p>
          Data is encrypted in transit (HTTPS). Sign-in tokens are kept in the iOS Keychain, and cloud data is only
          reachable from your authenticated account. No system is perfectly secure, but we work to protect your
          information and limit what we collect in the first place.
        </p>
      </>
    ),
  },
  {
    id: "rights",
    title: "Your rights",
    body: (
      <p>
        Depending on where you live (for example, the EU, UK or California), you may have the right to access, correct,
        export or delete your personal data, or object to certain processing. To exercise any of these rights, email{" "}
        {email}. We won't discriminate against you for making a request. Where we rely on consent (such as research
        sharing), you can withdraw it at any time in the app.
      </p>
    ),
  },
  {
    id: "children",
    title: "Children",
    body: (
      <p>
        {SITE.product} is not directed to children under 13, and we don't knowingly collect personal data from them. If
        you believe a child has given us personal data, contact us and we'll delete it.
      </p>
    ),
  },
  {
    id: "changes",
    title: "Changes to this policy",
    body: (
      <p>
        We'll update this page when our practices change and revise the "Last updated" date at the top. If a change
        materially affects how we use your data, we'll tell you in the app before it takes effect.
      </p>
    ),
  },
  {
    id: "contact",
    title: "Contact",
    body: (
      <p>
        {SITE.company} is responsible for your data under this policy. For privacy questions or requests, email {email}.
        For general help, visit{" "}
        <Link to="/support" className="text-link">
          Support
        </Link>
        .
      </p>
    ),
  },
];

export default function Privacy() {
  usePageTitle("Privacy Policy");

  return (
    <LegalPage
      eyebrow={`${SITE.product} · Legal`}
      title="Privacy Policy"
      intro={
        <p>
          This policy explains what data the {SITE.product} iPhone app and this website collect, how we use it and the
          choices you have. {SITE.product} is built by {SITE.company} ("we", "us").
        </p>
      }
      sections={SECTIONS}
    />
  );
}
