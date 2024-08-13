import { defineConfig } from 'vitepress'
import fs from 'fs'

// https://vitepress.dev/reference/site-config
export default defineConfig({
	title: "rbxlibs",
	description: "A collection of libraries for luau and roblox",
	lastUpdated: true,
	cleanUrls: true,
	lang: 'en-US',

	head: [
		['link', { rel: 'icon', href: '/rbxlibs_logo.svg' }]
	],

	markdown: {
		theme: {
			light: "catppuccin-latte",
			dark: "catppuccin-frappe"
		}
	},
	themeConfig: {
		lastUpdated: {
			text: 'Last edit',
			formatOptions: {
			  dateStyle: 'short',
			  timeStyle: 'short',
			  forceLocale: true,
			}
		  },

		logo: "/rbxlibs_logo_small.svg",
		editLink: {
			pattern: 'https://github.com/kalrnlo/rbxlibs/edit/main/docs/:path'
		},
		search: {
			provider: 'local',
		},

		// https://vitepress.dev/reference/default-theme-config
		socialLinks: [
			{ icon: 'github', link: 'https://github.com/kalrnlo/rbxlibs' },
			{ icon: 'discord', link: 'https://discord.gg/mchCdAFPWU' },
		],
		nav: [
			{ text: 'Donate', link: 'https://buymeacoffee.com/kalrnlo' },
		],

		sidebar: [
			{
				text: "Getting Started",
				items: [
					{ text: "Installing", link: "/installing" }
				]
			},
			{
				text: 'Libraries',
				items: JSON.parse(fs.readFileSync("docs/.vitepress/sidebar-libs.json", {
					encoding: 'utf8'
				}))
			}
		],
	}
})

