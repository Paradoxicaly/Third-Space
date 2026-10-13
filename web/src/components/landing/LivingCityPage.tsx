"use client";

import { useGSAP } from "@gsap/react";
import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import {
  ArrowDownRight,
  ArrowRight,
  ArrowUpRight,
  Check,
  Compass,
  MapPin,
  Menu,
  Search,
  ShieldCheck,
  Sparkles,
} from "lucide-react";
import Image from "next/image";
import { useRef, useState } from "react";

import { MotionProvider } from "@/components/motion/MotionProvider";
import { VantaScene } from "@/components/motion/VantaScene";
import { BlurText } from "@/components/react-bits/BlurText";
import { ClickSpark } from "@/components/react-bits/ClickSpark";
import { SpotlightCard } from "@/components/react-bits/SpotlightCard";

import { intents, places, quickFacts, useCases } from "./content";

export function LivingCityPage() {
  const root = useRef<HTMLElement>(null);
  const [selectedIntent, setSelectedIntent] = useState("All places");

  useGSAP(
    () => {
      if (
        process.env.NODE_ENV === "test" ||
        window.matchMedia("(prefers-reduced-motion: reduce)").matches
      ) {
        return;
      }

      const page = root.current;
      if (!page) return;

      gsap.registerPlugin(ScrollTrigger);
      const intro = gsap.timeline({ defaults: { ease: "power3.out" } });
      intro
        .from(".site-header", { y: -28, opacity: 0, duration: 0.72 })
        .from(".hero-kicker", { y: 22, opacity: 0, duration: 0.55 }, "-=0.35")
        .from(".hero-copy", { y: 24, opacity: 0, duration: 0.65 }, "-=0.3")
        .from(".intent-orbit", { scale: 0.88, opacity: 0, duration: 0.8 }, "-=0.45")
        .from(
          ".hero-stack__card",
          { x: 100, y: 60, rotate: 18, opacity: 0, duration: 0.85, stagger: 0.13 },
          "-=0.65",
        )
        .from(".hero-actions", { y: 24, opacity: 0, duration: 0.58 }, "-=0.48");

      gsap.utils.toArray<HTMLElement>("[data-reveal]").forEach((element) => {
        gsap.from(element, {
          y: 72,
          opacity: 0,
          duration: 0.9,
          ease: "power3.out",
          scrollTrigger: { trigger: element, start: "top 86%", once: true },
        });
      });

      gsap.to(".route-thread__fill", {
        scaleY: 1,
        ease: "none",
        scrollTrigger: {
          trigger: page,
          start: "top top",
          end: "bottom bottom",
          scrub: 0.45,
        },
      });

      gsap.to(".hero-orb--one", {
        yPercent: 34,
        xPercent: -12,
        rotate: 18,
        ease: "none",
        scrollTrigger: { trigger: ".hero", start: "top top", end: "bottom top", scrub: 1 },
      });
      gsap.to(".hero-stack", {
        yPercent: 18,
        rotate: -3,
        ease: "none",
        scrollTrigger: { trigger: ".hero", start: "top top", end: "bottom top", scrub: 1 },
      });
    },
    { scope: root },
  );

  return (
    <MotionProvider>
      <ClickSpark>
        <main ref={root} className="living-city">
          <div className="route-thread" aria-hidden="true">
            <span className="route-thread__track" />
            <span className="route-thread__fill" />
          </div>

          <section className="hero" aria-labelledby="hero-title">
            <VantaScene />
            <div className="hero-noise" aria-hidden="true" />
            <div className="hero-orb hero-orb--one" aria-hidden="true" />
            <div className="hero-orb hero-orb--two" aria-hidden="true" />

            <header className="site-header shell">
              <a className="brand" href="#top" aria-label="Third Spaces home">
                <span className="brand-mark" aria-hidden="true">
                  <span />
                  <span />
                  <span />
                </span>
                <span>Third Spaces</span>
              </a>
              <nav className="desktop-nav" aria-label="Primary navigation">
                <a href="#places">Discover</a>
                <a href="#how-it-works">How it works</a>
                <a href="#submit">Add a place</a>
              </nav>
              <a className="header-cta" href="#places">
                Explore Carson <ArrowUpRight aria-hidden="true" />
              </a>
              <button className="menu-button" type="button" aria-label="Open navigation menu">
                <Menu aria-hidden="true" />
              </button>
            </header>

            <div className="hero-grid shell" id="top">
              <div className="hero-content">
                <p className="eyebrow hero-kicker">
                  <span className="pulse-dot" aria-hidden="true" />
                  Carson, California · pilot edition
                </p>
                <h1 id="hero-title">
                  <BlurText text="Find your place between home and everything else." />
                </h1>
                <p className="hero-copy">
                  Discover places to focus, meet, move, create, and breathe—chosen for how they
                  feel, not just what they sell.
                </p>

                <div className="intent-picker" aria-label="Choose what you need a place for">
                  <div className="intent-picker__header">
                    <span>What do you need right now?</span>
                    <Sparkles aria-hidden="true" />
                  </div>
                  <div className="intent-pills">
                    {intents.map((intent) => {
                      const Icon = intent.icon;
                      const selected = selectedIntent === intent.name;
                      return (
                        <button
                          key={intent.name}
                          className="intent-pill"
                          type="button"
                          aria-pressed={selected}
                          onClick={() => setSelectedIntent(intent.name)}
                        >
                          <Icon aria-hidden="true" />
                          {intent.name}
                        </button>
                      );
                    })}
                  </div>
                  <p className="intent-status" role="status" aria-live="polite">
                    {selectedIntent === "All places"
                      ? "Choose an intent to shape your route"
                      : `Showing places for ${selectedIntent}`}
                  </p>
                </div>

                <div className="hero-actions">
                  <a className="button button--primary" href="#places">
                    <Search aria-hidden="true" />
                    Explore around Carson
                    <ArrowRight aria-hidden="true" />
                  </a>
                  <a className="button button--ghost" href="#submit">
                    Submit a place
                    <ArrowDownRight aria-hidden="true" />
                  </a>
                </div>
              </div>

              <div className="hero-visual" aria-label="A preview of places around Carson">
                <div className="intent-orbit" aria-hidden="true">
                  <span>FOCUS</span>
                  <span>MEET</span>
                  <span>MOVE</span>
                  <span>CREATE</span>
                </div>
                <div className="map-sketch" aria-hidden="true">
                  <svg viewBox="0 0 520 620" role="presentation">
                    <path d="M-30 170 C120 120, 130 280, 270 224 S435 106, 560 180" />
                    <path d="M40 660 C30 470, 250 510, 236 350 S380 170, 510 40" />
                    <path d="M-20 398 C150 345, 320 455, 550 340" />
                  </svg>
                  <span className="map-label map-label--one">CARSON</span>
                  <span className="map-label map-label--two">DOMINGUEZ</span>
                  <span className="map-pin map-pin--one"><MapPin /></span>
                  <span className="map-pin map-pin--two"><MapPin /></span>
                  <span className="map-pin map-pin--three"><MapPin /></span>
                </div>
                <div className="hero-stack">
                  {places.map((place, index) => (
                    <article
                      className={`hero-stack__card hero-stack__card--${index + 1}`}
                      key={place.name}
                    >
                      <Image src={place.image} alt="" fill sizes="(max-width: 900px) 70vw, 30vw" />
                      <div className="hero-stack__shade" />
                      <div className="hero-stack__meta">
                        <span>{place.category}</span>
                        <strong>{place.name}</strong>
                        <small>{place.location}</small>
                      </div>
                    </article>
                  ))}
                </div>
                <div className="floating-note floating-note--top">
                  <span className="floating-note__icon"><Compass /></span>
                  <span><b>Not a restaurant list.</b><small>A map for real life.</small></span>
                </div>
                <div className="floating-note floating-note--bottom">
                  <span className="avatars" aria-hidden="true"><i /><i /><i /></span>
                  <span><b>Built with locals</b><small>Every submission reviewed</small></span>
                </div>
              </div>
            </div>

            <div className="hero-footer shell" aria-hidden="true">
              <span>Scroll to wander</span>
              <span className="hero-footer__line" />
              <span>33.8317° N · 118.2820° W</span>
            </div>
          </section>

          <section className="ticker" aria-label="What Third Spaces helps you find">
            <div className="ticker__track">
              {[...useCases, ...useCases].map(({ label, icon: Icon }, index) => (
                <span key={`${label}-${index}`}>
                  <Icon aria-hidden="true" /> {label} <i>✦</i>
                </span>
              ))}
            </div>
          </section>

          <section className="intent-section shell" id="how-it-works" aria-labelledby="intent-title">
            <div className="section-heading" data-reveal>
              <p className="eyebrow">Start with a feeling</p>
              <h2 id="intent-title">A better question than “what’s nearby?”</h2>
              <p>Tell us what the moment needs. We’ll surface the places that fit it.</p>
            </div>
            <div className="intent-bento">
              {intents.map((intent, index) => {
                const Icon = intent.icon;
                return (
                  <SpotlightCard
                    key={intent.name}
                    className={`intent-tile intent-tile--${index + 1}`}
                    spotlightColor={index % 2 ? "rgba(58, 123, 116, .32)" : undefined}
                  >
                    <span className="intent-tile__number">0{index + 1}</span>
                    <Icon className="intent-tile__icon" aria-hidden="true" />
                    <h3>{intent.name}</h3>
                    <p>{intent.note}</p>
                    <ArrowUpRight className="intent-tile__arrow" aria-hidden="true" />
                  </SpotlightCard>
                );
              })}
            </div>
          </section>

          <section className="places-section" id="places" aria-label="Places around Carson">
            <div className="shell">
              <div className="section-heading section-heading--row" data-reveal>
                <div>
                  <p className="eyebrow">Around Carson</p>
                  <h2>Places with a pulse.</h2>
                </div>
                <p>Early visual prototypes for the moderated Carson-area pilot.</p>
              </div>

              <div className="place-grid">
                {places.map((place) => {
                  const Icon = place.icon;
                  return (
                    <SpotlightCard key={place.name} className="place-card">
                      <div className="place-card__image">
                        <Image src={place.image} alt={place.alt} fill sizes="(max-width: 800px) 92vw, 31vw" />
                        <div className="place-card__topline">
                          <span><Icon aria-hidden="true" /> {place.category}</span>
                          <span className="verified"><Check aria-hidden="true" /> Verified</span>
                        </div>
                      </div>
                      <div className="place-card__body">
                        <p className="place-card__location"><MapPin aria-hidden="true" /> {place.location}</p>
                        <h3>{place.name}</h3>
                        <p>{place.note}</p>
                        <ul aria-label={`Features of ${place.name}`}>
                          {place.meta.map((item) => <li key={item}>{item}</li>)}
                        </ul>
                        <a href="#submit" aria-label={`Preview ${place.name}`}>
                          Open the field note <ArrowUpRight aria-hidden="true" />
                        </a>
                      </div>
                    </SpotlightCard>
                  );
                })}
              </div>
            </div>
          </section>

          <section className="manifesto shell" data-reveal>
            <div className="manifesto__stamp" aria-hidden="true">
              <span>THIRD</span><strong>✦</strong><span>SPACES</span>
            </div>
            <p className="eyebrow">The space in between</p>
            <h2>
              Cities aren’t just where we <em>live</em> and <em>work</em>. They’re where we
              become ourselves.
            </h2>
            <div className="manifesto__aside">
              <p>
                Third Spaces makes the overlooked visible—the library table, shaded trail,
                community garden, quiet café corner, and neighborhood view that asks nothing
                more than for you to stay awhile.
              </p>
            </div>
          </section>

          <section className="trust-section" id="submit">
            <div className="shell trust-grid">
              <div data-reveal>
                <p className="eyebrow eyebrow--light">Local knowledge, carefully handled</p>
                <h2>Found somewhere that belongs on the map?</h2>
                <p className="trust-copy">
                  Tell us what makes it useful. A moderator checks every place and correction
                  before anyone else sees it.
                </p>
                <a className="button button--cream" href="mailto:places@thirdspaces.local">
                  Send a place for review <ArrowUpRight aria-hidden="true" />
                </a>
              </div>
              <div className="moderation-card" data-reveal>
                <div className="moderation-card__icon"><ShieldCheck aria-hidden="true" /></div>
                <p className="eyebrow">The review path</p>
                <ol>
                  <li><span>01</span><div><b>You share the place</b><small>Details, photos, and why it works.</small></div></li>
                  <li><span>02</span><div><b>A moderator checks it</b><small>Location, safety, attribution, and accuracy.</small></div></li>
                  <li><span>03</span><div><b>It joins the living map</b><small>With a visible freshness date.</small></div></li>
                </ol>
              </div>
            </div>
          </section>

          <section className="facts shell" aria-label="Third Spaces pilot facts">
            {quickFacts.map((fact) => (
              <div key={fact.value} data-reveal>
                <strong>{fact.value}</strong>
                <span>{fact.label}</span>
              </div>
            ))}
          </section>

          <footer className="site-footer shell">
            <a className="brand" href="#top"><span className="brand-mark" aria-hidden="true"><span /><span /><span /></span>Third Spaces</a>
            <p>Find somewhere worth staying.</p>
            <span>Carson pilot · 2026</span>
          </footer>
        </main>
      </ClickSpark>
    </MotionProvider>
  );
}
