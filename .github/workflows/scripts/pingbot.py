import os
import requests
import json

GITHUB_TOKEN = os.getenv('GITHUB_TOKEN')
MAINTAINER = 'GertjanBisschop'
REPO_OWNER = 'eu-parc'
REPO_NAME = os.getenv('REPO_NAME').split('/')[1]  # Extract the repository name

def get_issue_details(issue_number):
    url = f'https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/issues/{issue_number}'
    headers = {'Authorization': f'token {GITHUB_TOKEN}'}
    response = requests.get(url, headers=headers)
    return response.json()

def ping_user(issue_number, user):
    comment = f'@{user}, you have been mentioned in issue #{issue_number}.'
    url = f'https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/issues/{issue_number}/comments'
    headers = {'Authorization': f'token {GITHUB_TOKEN}'}
    data = {'body': comment}
    requests.post(url, headers=headers, json=data)

def load_mapping(file_path):
    with open(file_path, 'r') as file:
        return json.load(file)

def main():
    issue_number = os.getenv('ISSUE_NUMBER')
    issue_details = get_issue_details(issue_number)
    issue_body = issue_details['body']

    mapping = load_mapping('.github/scripts/expertise_mapping.json')  # Change to .yaml if using YAML

    sent_ping = False
    for domain, user in mapping.items():
        if f'[ ] {domain}' in issue_body:
            ping_user(issue_number, user)
            sent_ping = True
            break  # Assuming only one domain will be ticked
    if not sent_ping:
        ping_user(issue_number, MAINTAINER)

if __name__ == '__main__':
    main()