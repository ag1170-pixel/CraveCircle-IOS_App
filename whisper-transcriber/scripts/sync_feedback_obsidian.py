#!/usr/bin/env python3
"""
sync_feedback_obsidian.py

This script fetches new Product-Market Fit (PMF) feedback from the CraveCircle 
database (Supabase) and appends it to the Obsidian vault for team analysis.

Usage:
  python3 sync_feedback_obsidian.py
"""

import os
import datetime
import json

# Configuration
OBSIDIAN_VAULT_PATH = "/Users/user38/SergantSwaggBase/Projects/CraveCircle/CraveCircle_UserFeedback.md"

def fetch_feedbacks_from_db():
    """
    Simulates fetching un-synced feedback from the Supabase 'feedbacks' table.
    In production, this would use the supabase-py client:
    supabase.table('feedbacks').select('*').eq('synced_to_obsidian', False).execute()
    """
    print("Fetching new feedback from Supabase...")
    
    # Mocking some data that would come from the iOS app
    return [
        {
            "id": "fbdk-1234",
            "created_at": datetime.datetime.now().isoformat(),
            "user_id": "test-user-1",
            "disappointment_level": "Very disappointed",
            "fans_commonality": "They all love cooking but don't have time to read long blogs.",
            "improvements": "Make it easier to share recipes to WhatsApp directly.",
            "additional": "Love the floating chef mascot!"
        }
    ]

def mark_as_synced(feedback_ids):
    """
    Simulates marking the feedbacks as synced in the database so they aren't fetched again.
    """
    print(f"Marked {len(feedback_ids)} feedbacks as synced in Supabase.")

def append_to_obsidian(feedbacks):
    """
    Formats the feedbacks as markdown and appends them to the Obsidian vault.
    """
    if not feedbacks:
        print("No new feedback to sync.")
        return

    print(f"Syncing {len(feedbacks)} feedbacks to Obsidian...")
    
    # Create the file with a header if it doesn't exist
    if not os.path.exists(OBSIDIAN_VAULT_PATH):
        with open(OBSIDIAN_VAULT_PATH, "w") as f:
            f.write("# CraveCircle User Feedback (PMF)\n\n")
            f.write("All feedback from the iOS app is synced here automatically for analysis.\n\n")
            f.write("---\n\n")

    with open(OBSIDIAN_VAULT_PATH, "a") as f:
        for fb in feedbacks:
            date_str = datetime.datetime.fromisoformat(fb["created_at"]).strftime("%Y-%m-%d %H:%M")
            
            f.write(f"## Feedback: {date_str} (ID: {fb['id'][:8]})\n")
            
            # Use Obsidian callouts for visual distinction
            if fb["disappointment_level"] == "Very disappointed":
                f.write(f"> [!success] PMF Signal: {fb['disappointment_level']}\n")
            elif fb["disappointment_level"] == "Somewhat disappointed":
                f.write(f"> [!warning] PMF Signal: {fb['disappointment_level']}\n")
            else:
                f.write(f"> [!danger] PMF Signal: {fb['disappointment_level']}\n")
                
            f.write("> User would be highly impacted without CraveCircle.\n\n")
            
            f.write("**What do our biggest fans have in common?**\n")
            f.write(f"{fb['fans_commonality']}\n\n")
            
            f.write("**What could we improve?**\n")
            f.write(f"{fb['improvements']}\n\n")
            
            if fb.get("additional"):
                f.write("**Additional Magic/Notes:**\n")
                f.write(f"{fb['additional']}\n\n")
                
            f.write("---\n\n")

    print(f"Successfully appended to {OBSIDIAN_VAULT_PATH}")

if __name__ == "__main__":
    new_feedbacks = fetch_feedbacks_from_db()
    if new_feedbacks:
        append_to_obsidian(new_feedbacks)
        mark_as_synced([fb["id"] for fb in new_feedbacks])
